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
# FAST PATH — exit immediately if no .feature files or test-specs.md staged
# ============================================================================

STAGED_FEATURE_FILES=$(git diff --cached --name-only 2>/dev/null | grep -E 'tests/features/.*\.feature$') || true
STAGED_TEST_SPECS=$(git diff --cached --name-only 2>/dev/null | grep 'test-specs\.md$') || true

if [[ -z "$STAGED_FEATURE_FILES" ]] && [[ -z "$STAGED_TEST_SPECS" ]]; then
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
# CONTEXT FILE — read stored hashes (per-feature, derived from test-specs.md path)
# ============================================================================

# ============================================================================
# SLOW PATH — verify staged .feature files and/or test-specs.md
# ============================================================================

BLOCKED=false
BLOCK_MESSAGES=()

# Capture all staged files once for context.json co-staging detection
STAGED_FILES_ALL=$(git diff --cached --name-only 2>/dev/null) || true

# ============================================================================
# .feature file verification (new format)
# Groups staged .feature files by feature directory, computes combined hash
# ============================================================================

if [[ -n "$STAGED_FEATURE_FILES" ]]; then
    # Group staged .feature files by feature directory
    # e.g., specs/001-feature/tests/features/login.feature -> specs/001-feature
    declare -A FEATURE_DIRS_MAP
    while IFS= read -r staged_path; do
        [[ -z "$staged_path" ]] && continue
        # Derive feature dir: specs/NNN/tests/features/x.feature -> specs/NNN
        FEATURES_DIR=$(dirname "$staged_path")                    # tests/features
        TESTS_DIR=$(dirname "$FEATURES_DIR")                      # tests
        FEAT_DIR=$(dirname "$TESTS_DIR")                          # specs/NNN-feature
        FEATURE_DIRS_MAP["$FEAT_DIR"]=1
    done <<< "$STAGED_FEATURE_FILES"

    for FEAT_DIR in "${!FEATURE_DIRS_MAP[@]}"; do
        FEATURES_DIR_ABS="$REPO_ROOT/$FEAT_DIR/tests/features"
        CONTEXT_FILE="$REPO_ROOT/$FEAT_DIR/context.json"
        CONTEXT_REL_PATH="$FEAT_DIR/context.json"

        # Reconstruct the full features directory for hash computation:
        # 1. Start with all committed .feature files from HEAD
        # 2. Overlay any staged changes on top
        # This handles partial staging correctly (only some files staged)
        TEMP_FEATURES_DIR=$(mktemp -d)
        trap "rm -rf $TEMP_FEATURES_DIR" EXIT

        FEATURES_REL="$FEAT_DIR/tests/features"

        # Step 1: Get ALL committed .feature files from HEAD
        COMMITTED_FEATURES=$(git ls-tree --name-only "HEAD:$FEATURES_REL" 2>/dev/null | grep '\.feature$') || true
        while IFS= read -r fname; do
            [[ -z "$fname" ]] && continue
            git show "HEAD:$FEATURES_REL/$fname" > "$TEMP_FEATURES_DIR/$fname" 2>/dev/null || true
        done <<< "$COMMITTED_FEATURES"

        # Step 2: Overlay staged versions (these take precedence over HEAD)
        STAGED_FOR_FEAT=$(echo "$STAGED_FEATURE_FILES" | grep "^$FEAT_DIR/") || true
        while IFS= read -r staged_path; do
            [[ -z "$staged_path" ]] && continue
            BASENAME=$(basename "$staged_path")
            git show ":$staged_path" > "$TEMP_FEATURES_DIR/$BASENAME" 2>/dev/null || continue
        done <<< "$STAGED_FOR_FEAT"

        # Compute combined hash of the full reconstructed directory
        CURRENT_HASH=$(compute_assertion_hash "$TEMP_FEATURES_DIR")
        rm -rf "$TEMP_FEATURES_DIR"

        if [[ "$CURRENT_HASH" == "NO_ASSERTIONS" ]]; then
            continue
        fi

        # Check if context.json is also being staged
        CONTEXT_STAGED=false
        if echo "$STAGED_FILES_ALL" | grep -qF "$CONTEXT_REL_PATH"; then
            CONTEXT_STAGED=true
        fi

        # Read context.json (staged or committed version)
        CONTEXT_STATUS="missing"
        CONTEXT_JSON=""
        if [[ "$CONTEXT_STAGED" == true ]] && [[ -f "$CONTEXT_FILE" ]]; then
            CONTEXT_JSON=$(cat "$CONTEXT_FILE" 2>/dev/null)
        else
            CONTEXT_JSON=$(git show "HEAD:$CONTEXT_REL_PATH" 2>/dev/null) || true
        fi

        if [[ -n "$CONTEXT_JSON" ]] && echo "$CONTEXT_JSON" | jq empty 2>/dev/null; then
            STORED_HASH=$(echo "$CONTEXT_JSON" | jq -r '.testify.assertion_hash // ""' 2>/dev/null || echo "")
            # For .feature files, match by features_dir or presence of file_count
            STORED_DIR=$(echo "$CONTEXT_JSON" | jq -r '.testify.features_dir // ""' 2>/dev/null || echo "")

            if [[ -n "$STORED_HASH" ]] && [[ -n "$STORED_DIR" ]]; then
                if [[ "$STORED_HASH" == "$CURRENT_HASH" ]]; then
                    CONTEXT_STATUS="valid"
                else
                    CONTEXT_STATUS="invalid"
                fi
            fi
        fi

        # Combine results (git notes skipped for directory-based .feature files)
        HASH_STATUS="missing"
        if [[ "$CONTEXT_STAGED" == true ]] && [[ "$CONTEXT_STATUS" == "valid" ]]; then
            HASH_STATUS="valid"
        elif [[ "$CONTEXT_STATUS" == "invalid" ]]; then
            HASH_STATUS="invalid"
        elif [[ "$CONTEXT_STATUS" == "valid" ]]; then
            HASH_STATUS="valid"
        fi

        # Decision logic
        case "$HASH_STATUS" in
            valid)
                ;;
            invalid)
                BLOCKED=true
                BLOCK_MESSAGES+=("BLOCKED: $FEAT_DIR/tests/features/ — .feature assertion integrity check failed")
                BLOCK_MESSAGES+=("  .feature file assertions have been modified since /iikit-05-testify generated them.")
                BLOCK_MESSAGES+=("  Re-run /iikit-05-testify to regenerate .feature files.")
                ;;
            missing)
                if [[ "$TDD_DETERMINATION" == "mandatory" ]]; then
                    echo "[iikit] Warning: $FEAT_DIR/tests/features/ — no stored assertion hash found (TDD is mandatory)" >&2
                    echo "[iikit]   If this is the initial testify commit, this is expected." >&2
                    echo "[iikit]   Otherwise, run /iikit-05-testify to generate integrity hashes." >&2
                fi
                ;;
        esac
    done
fi

# ============================================================================
# Legacy test-specs.md verification (backward compatibility)
# ============================================================================

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

    # Derive per-feature context.json path from the test-specs.md path
    FEATURE_DIR=$(dirname "$(dirname "$staged_path")")
    CONTEXT_FILE="$REPO_ROOT/$FEATURE_DIR/context.json"
    CONTEXT_REL_PATH="$FEATURE_DIR/context.json"

    CONTEXT_STAGED=false
    if echo "$STAGED_FILES_ALL" | grep -qF "$CONTEXT_REL_PATH"; then
        CONTEXT_STAGED=true
    fi

    CONTEXT_STATUS="missing"
    CONTEXT_JSON=""
    if [[ "$CONTEXT_STAGED" == true ]] && [[ -f "$CONTEXT_FILE" ]]; then
        CONTEXT_JSON=$(cat "$CONTEXT_FILE" 2>/dev/null)
    else
        CONTEXT_JSON=$(git show "HEAD:$CONTEXT_REL_PATH" 2>/dev/null) || true
    fi

    if [[ -n "$CONTEXT_JSON" ]] && echo "$CONTEXT_JSON" | jq empty 2>/dev/null; then
        STORED_FILE=$(echo "$CONTEXT_JSON" | jq -r '.testify.test_specs_file // ""' 2>/dev/null || echo "")
        STORED_HASH=$(echo "$CONTEXT_JSON" | jq -r '.testify.assertion_hash // ""' 2>/dev/null || echo "")

        if [[ -n "$STORED_HASH" ]]; then
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
    NOTE_STATUS="missing"
    GIT_NOTES_REF="refs/notes/testify"
    NOTE_HASH=""
    for commit_sha in $(git rev-list HEAD -50 2>/dev/null); do
        NOTE_CONTENT=$(git notes --ref="$GIT_NOTES_REF" show "$commit_sha" 2>/dev/null) || continue
        if [[ -n "$NOTE_CONTENT" ]]; then
            NOTE_HASH=$(echo "$NOTE_CONTENT" | awk -v path="$staged_path" '
                /^testify-hash:/ { hash = $2 }
                /^test-specs-file:/ {
                    sub(/^test-specs-file:[[:space:]]*/, "")
                    file = $0
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
        fi
    done
    if [[ -n "$NOTE_HASH" ]]; then
        if [[ "$NOTE_HASH" == "$CURRENT_HASH" ]]; then
            NOTE_STATUS="valid"
        else
            NOTE_STATUS="invalid"
        fi
    fi

    HASH_STATUS="missing"
    if [[ "$CONTEXT_STAGED" == true ]] && [[ "$CONTEXT_STATUS" == "valid" ]]; then
        HASH_STATUS="valid"
    elif [[ "$NOTE_STATUS" == "invalid" ]] || [[ "$CONTEXT_STATUS" == "invalid" ]]; then
        HASH_STATUS="invalid"
    elif [[ "$NOTE_STATUS" == "valid" ]] || [[ "$CONTEXT_STATUS" == "valid" ]]; then
        HASH_STATUS="valid"
    fi

    case "$HASH_STATUS" in
        valid)
            ;;
        invalid)
            BLOCKED=true
            BLOCK_MESSAGES+=("BLOCKED: $staged_path — assertion integrity check failed")
            BLOCK_MESSAGES+=("  Assertions have been modified since /iikit-05-testify generated them.")
            BLOCK_MESSAGES+=("  Re-run /iikit-05-testify to regenerate test specifications.")
            ;;
        missing)
            if [[ "$TDD_DETERMINATION" == "mandatory" ]]; then
                echo "[iikit] Warning: $staged_path — no stored assertion hash found (TDD is mandatory)" >&2
                echo "[iikit]   If this is the initial testify commit, this is expected." >&2
                echo "[iikit]   Otherwise, run /iikit-05-testify to generate integrity hashes." >&2
            fi
            ;;
    esac
done <<< "$STAGED_TEST_SPECS"

# ============================================================================
# OUTPUT — report results
# ============================================================================

if [[ "$BLOCKED" == true ]]; then
    echo "" >&2
    echo "+-------------------------------------------------------------+" >&2
    echo "|  IIKIT PRE-COMMIT: ASSERTION INTEGRITY CHECK FAILED        |" >&2
    echo "+-------------------------------------------------------------+" >&2
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
