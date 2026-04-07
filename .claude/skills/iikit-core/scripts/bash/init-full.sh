#!/usr/bin/env bash
# BASH 3.2 REQUIRED — no associative arrays, no mapfile, no |&
#
# Combined init: git-setup + init-project + validate-premise in one call.
# Saves 2 tool call round-trips during /iikit-core init.
#
# Usage: bash init-full.sh [--json] [project-path]
# Output: JSON combining all three script outputs.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

JSON_MODE=false
PROJECT_PATH=""

for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        *) PROJECT_PATH="$arg" ;;
    esac
done

# Step 1: git-setup (environment detection)
GIT_JSON=$(bash "$SCRIPT_DIR/git-setup.sh" --json 2>/dev/null | grep '^{' | head -1)
if [[ -z "$GIT_JSON" ]]; then
    GIT_JSON='{"git_available":false,"is_git_repo":false,"has_remote":false,"remote_url":"","is_github_remote":false,"gh_available":false,"gh_authenticated":false,"has_iikit_artifacts":false}'
fi

# Step 2: init-project (hooks, git init)
INIT_JSON=$(bash "$SCRIPT_DIR/init-project.sh" --json 2>/dev/null | grep '^{' | head -1)
if [[ -z "$INIT_JSON" ]]; then
    INIT_JSON='{"success":false,"git_initialized":false,"hook_installed":false,"git_user_configured":true}'
fi

# Step 3: validate-premise (if PREMISE.md exists)
PREMISE_ARGS="--json"
[[ -n "$PROJECT_PATH" ]] && PREMISE_ARGS="$PREMISE_ARGS $PROJECT_PATH"
PREMISE_JSON=$(bash "$SCRIPT_DIR/validate-premise.sh" $PREMISE_ARGS 2>/dev/null | grep '^{' | head -1)
if [[ -z "$PREMISE_JSON" ]]; then
    PREMISE_JSON='{"status":"FAIL","sections_found":0,"sections_required":5,"placeholders_remaining":0,"missing_sections":["What","Who","Why","Domain","Scope"]}'
fi

# Combine outputs
if $JSON_MODE; then
    printf '{"git":%s,"init":%s,"premise":%s}\n' "$GIT_JSON" "$INIT_JSON" "$PREMISE_JSON"
else
    echo "=== Git Environment ==="
    echo "$GIT_JSON"
    echo ""
    echo "=== Project Init ==="
    echo "$INIT_JSON"
    echo ""
    echo "=== PREMISE.md ==="
    echo "$PREMISE_JSON"
fi
