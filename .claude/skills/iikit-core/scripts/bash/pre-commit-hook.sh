#!/usr/bin/env bash
# IIKIT-PRE-COMMIT
# Git pre-commit hook for assertion integrity enforcement
# Prevents committing tampered test-specs.md assertions
#
# This is a thin wrapper that sources testify-tdd.sh at runtime
# to reuse existing functions (compute_assertion_hash, verify_assertion_hash, etc.)
#
# Installation: Automatically installed by init-project.sh
# Manual: cp pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

# ============================================================================
# PATH DETECTION — find the scripts directory at runtime
# ============================================================================

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
    # Not a git repo — should not happen in a hook, but be safe
    exit 0
fi

SCRIPTS_DIR=""
CANDIDATE_PATHS=(
    "$REPO_ROOT/.claude/skills/iikit-core/scripts/bash"
    "$REPO_ROOT/.tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash"
    "$REPO_ROOT/.codex/skills/iikit-core/scripts/bash"
)

for candidate in "${CANDIDATE_PATHS[@]}"; do
    if [[ -f "$candidate/testify-tdd.sh" ]]; then
        SCRIPTS_DIR="$candidate"
        break
    fi
done

if [[ -z "$SCRIPTS_DIR" ]]; then
    echo "[iikit] Warning: IIKit scripts not found — skipping assertion integrity check" >&2
    exit 0
fi

# ============================================================================
# FAST PATH — exit immediately if no test-specs.md is staged
# ============================================================================

STAGED_TEST_SPECS=$(git diff --cached --name-only 2>/dev/null | grep 'test-specs\.md$') || true

if [[ -z "$STAGED_TEST_SPECS" ]]; then
    exit 0
fi

# ============================================================================
# SOURCE FUNCTIONS — load testify-tdd.sh (which sources common.sh)
# ============================================================================

# testify-tdd.sh has a main block that only runs when $# > 0,
# so sourcing it just loads the functions
source "$SCRIPTS_DIR/testify-tdd.sh"

# ============================================================================
# TDD DETERMINATION — check constitution for TDD requirements
# ============================================================================

CONSTITUTION_FILE="$REPO_ROOT/CONSTITUTION.md"
TDD_DETERMINATION="unknown"
if [[ -f "$CONSTITUTION_FILE" ]]; then
    TDD_DETERMINATION=$(get_tdd_determination "$CONSTITUTION_FILE")
fi

# ============================================================================
# CONTEXT FILE — read stored hashes
# ============================================================================

CONTEXT_FILE="$REPO_ROOT/.specify/context.json"

# ============================================================================
# SLOW PATH — verify each staged test-specs.md
# ============================================================================

BLOCKED=false
BLOCK_MESSAGES=()

# Capture all staged files once for context.json co-staging detection
STAGED_FILES_ALL=$(git diff --cached --name-only 2>/dev/null) || true

while IFS= read -r staged_path; do
    [[ -z "$staged_path" ]] && continue

    # Extract staged version to a temp file (check what's being committed)
    TEMP_FILE=$(mktemp)
    trap "rm -f $TEMP_FILE" EXIT

    if ! git show ":$staged_path" > "$TEMP_FILE" 2>/dev/null; then
        rm -f "$TEMP_FILE"
        continue
    fi

    # Compute hash of the staged version
    CURRENT_HASH=$(compute_assertion_hash "$TEMP_FILE")
    rm -f "$TEMP_FILE"

    # Skip if no assertions in the file
    if [[ "$CURRENT_HASH" == "NO_ASSERTIONS" ]]; then
        continue
    fi

    # Check if context.json is ALSO being staged in this commit
    # (indicates testify is committing its output — test-specs.md + context.json together)
    CONTEXT_STAGED=false
    if echo "$STAGED_FILES_ALL" | grep -q '\.specify/context\.json$'; then
        CONTEXT_STAGED=true
    fi

    # Check against context.json
    # When context.json is staged (testify commit), read from working tree.
    # When NOT staged, read from HEAD (committed version) to prevent
    # working-tree forgery (A8b: attacker modifies context.json without staging).
    CONTEXT_STATUS="missing"
    CONTEXT_JSON=""
    if [[ "$CONTEXT_STAGED" == true ]] && [[ -f "$CONTEXT_FILE" ]]; then
        # Testify commit: read working tree (testify just wrote it)
        CONTEXT_JSON=$(cat "$CONTEXT_FILE" 2>/dev/null)
    else
        # Not staged: read committed version from HEAD (tamper-resistant)
        CONTEXT_JSON=$(git show HEAD:.specify/context.json 2>/dev/null) || true
    fi

    if [[ -n "$CONTEXT_JSON" ]] && echo "$CONTEXT_JSON" | jq empty 2>/dev/null; then
        STORED_FILE=$(echo "$CONTEXT_JSON" | jq -r '.testify.test_specs_file // ""' 2>/dev/null || echo "")
        STORED_HASH=$(echo "$CONTEXT_JSON" | jq -r '.testify.assertion_hash // ""' 2>/dev/null || echo "")

        if [[ -n "$STORED_HASH" ]]; then
            # Match by path: stored file must end with the staged path
            if [[ "$STORED_FILE" == *"/$staged_path" ]] || [[ "$STORED_FILE" == "$staged_path" ]]; then
                if [[ "$STORED_HASH" == "$CURRENT_HASH" ]]; then
                    CONTEXT_STATUS="valid"
                else
                    CONTEXT_STATUS="invalid"
                fi
            fi
        fi
    fi

    # Check git notes (tamper-resistant)
    # Search backward through recent commits to find the most recent testify note
    # that matches THIS specific test-specs.md file (by path).
    # Notes may contain multiple entries (separated by ---) when multiple
    # test-specs.md files were committed together.
    NOTE_STATUS="missing"
    GIT_NOTES_REF="refs/notes/testify"
    NOTE_HASH=""
    for commit_sha in $(git rev-list HEAD -50 2>/dev/null); do
        NOTE_CONTENT=$(git notes --ref="$GIT_NOTES_REF" show "$commit_sha" 2>/dev/null) || continue
        if [[ -n "$NOTE_CONTENT" ]]; then
            # Parse multi-entry notes: extract hash for the matching file
            NOTE_HASH=$(echo "$NOTE_CONTENT" | awk -v path="$staged_path" '
                /^testify-hash:/ { hash = $2 }
                /^test-specs-file:/ {
                    sub(/^test-specs-file:[[:space:]]*/, "")
                    file = $0
                    # Match: stored file ends with staged path, or exact match
                    if (file == path || index(file, "/" path) == length(file) - length("/" path) + 1) {
                        print hash
                        exit
                    }
                }
                /^---$/ { hash = "" }
            ')
            if [[ -n "$NOTE_HASH" ]]; then
                break
            fi
            # Note exists but no matching file — keep searching older commits
        fi
    done
    if [[ -n "$NOTE_HASH" ]]; then
        if [[ "$NOTE_HASH" == "$CURRENT_HASH" ]]; then
            NOTE_STATUS="valid"
        else
            NOTE_STATUS="invalid"
        fi
    fi

    # Combine results
    # When context.json is staged alongside test-specs.md and hashes match,
    # this is a testify commit (new/updated assertions with fresh hash).
    # The old git note from a previous testify run is expected to not match.
    # When context.json is NOT staged, only test-specs.md is changing —
    # git note "invalid" overrides context "valid" (catches double-tamper
    # where agent modifies context.json in working tree but only stages test-specs.md).
    HASH_STATUS="missing"
    if [[ "$CONTEXT_STAGED" == true ]] && [[ "$CONTEXT_STATUS" == "valid" ]]; then
        # Testify commit: context.json staged with matching hash → trust it
        HASH_STATUS="valid"
    elif [[ "$NOTE_STATUS" == "invalid" ]] || [[ "$CONTEXT_STATUS" == "invalid" ]]; then
        HASH_STATUS="invalid"
    elif [[ "$NOTE_STATUS" == "valid" ]] || [[ "$CONTEXT_STATUS" == "valid" ]]; then
        HASH_STATUS="valid"
    fi

    # Decision logic
    case "$HASH_STATUS" in
        valid)
            # PASS — silent
            ;;
        invalid)
            # BLOCK — assertions tampered
            BLOCKED=true
            BLOCK_MESSAGES+=("BLOCKED: $staged_path — assertion integrity check failed")
            BLOCK_MESSAGES+=("  Assertions have been modified since /iikit-05-testify generated them.")
            BLOCK_MESSAGES+=("  Re-run /iikit-05-testify to regenerate test specifications.")
            ;;
        missing)
            if [[ "$TDD_DETERMINATION" == "mandatory" ]]; then
                # WARN — could be initial testify commit
                echo "[iikit] Warning: $staged_path — no stored assertion hash found (TDD is mandatory)" >&2
                echo "[iikit]   If this is the initial testify commit, this is expected." >&2
                echo "[iikit]   Otherwise, run /iikit-05-testify to generate integrity hashes." >&2
            fi
            # Allow in both cases (missing hash doesn't block)
            ;;
    esac
done <<< "$STAGED_TEST_SPECS"

# ============================================================================
# OUTPUT — report results
# ============================================================================

if [[ "$BLOCKED" == true ]]; then
    echo "" >&2
    echo "╭─────────────────────────────────────────────────────────────╮" >&2
    echo "│  IIKIT PRE-COMMIT: ASSERTION INTEGRITY CHECK FAILED        │" >&2
    echo "╰─────────────────────────────────────────────────────────────╯" >&2
    echo "" >&2
    for msg in "${BLOCK_MESSAGES[@]}"; do
        echo "[iikit] $msg" >&2
    done
    echo "" >&2
    echo "[iikit] To fix: Re-run /iikit-05-testify to regenerate test specs with valid hashes." >&2
    echo "[iikit] To bypass (NOT recommended): git commit --no-verify" >&2
    echo "" >&2
    exit 1
fi

exit 0
