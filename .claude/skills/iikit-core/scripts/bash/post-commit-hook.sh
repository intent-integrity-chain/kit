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
# FAST PATH — exit if no .feature files or test-specs.md in the commit
# ============================================================================

COMMITTED_FEATURE_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | grep -E 'tests/features/.*\.feature$') || true
COMMITTED_TEST_SPECS=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | grep 'test-specs\.md$') || true

if [[ -z "$COMMITTED_FEATURE_FILES" ]] && [[ -z "$COMMITTED_TEST_SPECS" ]]; then
    exit 0
fi

# ============================================================================
# SOURCE FUNCTIONS — load testify-tdd.sh (which sources common.sh)
# ============================================================================

source "$SCRIPTS_DIR/testify-tdd.sh"

# ============================================================================
# STORE GIT NOTES — for committed .feature files and/or test-specs.md
# Git only allows ONE note per commit per namespace, so all entries
# are accumulated into a single note separated by "---" markers.
# ============================================================================

# Preserve any existing note content (from a previous testify on this commit)
EXISTING_NOTE=$(git notes --ref="$GIT_NOTES_REF" show HEAD 2>/dev/null) || true
FULL_NOTE="$EXISTING_NOTE"

# --- .feature files: group by feature directory, compute combined hash ---
if [[ -n "$COMMITTED_FEATURE_FILES" ]]; then
    declare -A COMMITTED_FEAT_DIRS
    while IFS= read -r committed_path; do
        [[ -z "$committed_path" ]] && continue
        FEATURES_DIR=$(dirname "$committed_path")
        TESTS_DIR=$(dirname "$FEATURES_DIR")
        FEAT_DIR=$(dirname "$TESTS_DIR")
        COMMITTED_FEAT_DIRS["$FEAT_DIR"]=1
    done <<< "$COMMITTED_FEATURE_FILES"

    for FEAT_DIR in "${!COMMITTED_FEAT_DIRS[@]}"; do
        # Extract all committed .feature files for this feature to temp dir
        TEMP_FEATURES_DIR=$(mktemp -d)
        FEAT_FILES=$(echo "$COMMITTED_FEATURE_FILES" | grep "^$FEAT_DIR/")
        while IFS= read -r committed_path; do
            [[ -z "$committed_path" ]] && continue
            BASENAME=$(basename "$committed_path")
            git show "HEAD:$committed_path" > "$TEMP_FEATURES_DIR/$BASENAME" 2>/dev/null || continue
        done <<< "$FEAT_FILES"

        CURRENT_HASH=$(compute_assertion_hash "$TEMP_FEATURES_DIR")
        rm -rf "$TEMP_FEATURES_DIR"

        if [[ "$CURRENT_HASH" == "NO_ASSERTIONS" ]]; then
            continue
        fi

        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        FEATURES_REL_PATH="$FEAT_DIR/tests/features"
        ENTRY="testify-hash: $CURRENT_HASH
generated-at: $TIMESTAMP
features-dir: $FEATURES_REL_PATH"

        # Remove any existing entry for this features dir
        if [[ -n "$FULL_NOTE" ]]; then
            FULL_NOTE=$(echo "$FULL_NOTE" | awk -v path="$FEATURES_REL_PATH" '
                BEGIN { skip=0 }
                /^testify-hash:/ { skip=0 }
                /^features-dir:/ && $0 ~ path { skip=1 }
                /^---$/ { if(skip) { skip=0; next } }
                !skip { print }
            ')
        fi

        if [[ -n "$FULL_NOTE" ]]; then
            FULL_NOTE="$FULL_NOTE
---
$ENTRY"
        else
            FULL_NOTE="$ENTRY"
        fi

        echo "[iikit] Assertion hash stored as git note for $FEATURES_REL_PATH" >&2
    done
fi

# --- Legacy test-specs.md files ---
while IFS= read -r committed_path; do
    [[ -z "$committed_path" ]] && continue

    TEMP_FILE=$(mktemp)
    if ! git show "HEAD:$committed_path" > "$TEMP_FILE" 2>/dev/null; then
        rm -f "$TEMP_FILE"
        continue
    fi

    CURRENT_HASH=$(compute_assertion_hash "$TEMP_FILE")
    rm -f "$TEMP_FILE"

    if [[ "$CURRENT_HASH" == "NO_ASSERTIONS" ]]; then
        continue
    fi

    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    ENTRY="testify-hash: $CURRENT_HASH
generated-at: $TIMESTAMP
test-specs-file: $committed_path"

    if [[ -n "$FULL_NOTE" ]]; then
        FULL_NOTE=$(echo "$FULL_NOTE" | awk -v path="$committed_path" '
            BEGIN { skip=0 }
            /^testify-hash:/ { skip=0 }
            /^test-specs-file:/ && $0 ~ path { skip=1 }
            /^---$/ { if(skip) { skip=0; next } }
            !skip { print }
        ')
    fi

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
