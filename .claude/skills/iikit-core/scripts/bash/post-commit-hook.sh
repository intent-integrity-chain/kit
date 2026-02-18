#!/usr/bin/env bash
# IIKIT-POST-COMMIT
# Git post-commit hook for tamper-resistant assertion hash storage
# Stores assertion hashes as git notes when test-specs.md is committed
#
# This closes the gap where an agent could tamper with both test-specs.md
# AND context.json to bypass the pre-commit check. Git notes are stored
# in the object database and are much harder to silently modify.
#
# Installation: Automatically installed by init-project.sh
# Manual: cp post-commit-hook.sh .git/hooks/post-commit && chmod +x .git/hooks/post-commit

# ============================================================================
# PATH DETECTION — find the scripts directory at runtime
# ============================================================================

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
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
    exit 0
fi

# ============================================================================
# FAST PATH — exit if no test-specs.md in the commit that just landed
# ============================================================================

COMMITTED_TEST_SPECS=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | grep 'test-specs\.md$') || true

if [[ -z "$COMMITTED_TEST_SPECS" ]]; then
    exit 0
fi

# ============================================================================
# SOURCE FUNCTIONS — load testify-tdd.sh (which sources common.sh)
# ============================================================================

source "$SCRIPTS_DIR/testify-tdd.sh"

# ============================================================================
# STORE GIT NOTES — for each committed test-specs.md
# Git only allows ONE note per commit per namespace, so when multiple
# test-specs.md files are committed together, we accumulate all entries
# into a single note separated by "---" markers.
# ============================================================================

# Preserve any existing note content (from a previous testify on this commit)
EXISTING_NOTE=$(git notes --ref="$GIT_NOTES_REF" show HEAD 2>/dev/null) || true
FULL_NOTE="$EXISTING_NOTE"

while IFS= read -r committed_path; do
    [[ -z "$committed_path" ]] && continue

    # Get the committed version from HEAD
    TEMP_FILE=$(mktemp)
    if ! git show "HEAD:$committed_path" > "$TEMP_FILE" 2>/dev/null; then
        rm -f "$TEMP_FILE"
        continue
    fi

    # Compute hash of the committed version
    CURRENT_HASH=$(compute_assertion_hash "$TEMP_FILE")
    rm -f "$TEMP_FILE"

    # Skip if no assertions
    if [[ "$CURRENT_HASH" == "NO_ASSERTIONS" ]]; then
        continue
    fi

    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    ENTRY="testify-hash: $CURRENT_HASH
generated-at: $TIMESTAMP
test-specs-file: $committed_path"

    # Remove any existing entry for this same file (from a previous note on this commit)
    if [[ -n "$FULL_NOTE" ]]; then
        FULL_NOTE=$(echo "$FULL_NOTE" | awk -v path="$committed_path" '
            BEGIN { skip=0 }
            /^testify-hash:/ { skip=0 }
            /^test-specs-file:/ && $0 ~ path { skip=1 }
            /^---$/ { if(skip) { skip=0; next } }
            !skip { print }
        ')
    fi

    # Append new entry
    if [[ -n "$FULL_NOTE" ]]; then
        FULL_NOTE="$FULL_NOTE
---
$ENTRY"
    else
        FULL_NOTE="$ENTRY"
    fi

    echo "[iikit] Assertion hash stored as git note for $committed_path" >&2

done <<< "$COMMITTED_TEST_SPECS"

# Write the accumulated note
if [[ -n "$FULL_NOTE" ]]; then
    echo "$FULL_NOTE" | git notes --ref="$GIT_NOTES_REF" add -f -F - HEAD 2>/dev/null
fi

exit 0
