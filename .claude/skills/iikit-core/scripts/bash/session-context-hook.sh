#!/usr/bin/env bash
# SessionStart hook: restore IIKit feature context after /clear
#
# Outputs feature context as additionalContext so Claude knows
# where the user is in the IIKit workflow after a context reset.

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO_ROOT=$(get_repo_root 2>/dev/null) || exit 0

# Check if this is an IIKit project
if [[ ! -f "$REPO_ROOT/CONSTITUTION.md" ]] && [[ ! -d "$REPO_ROOT/.specify" ]]; then
    exit 0
fi

# Try to detect active feature
FEATURE=""
FEATURE=$(read_active_feature "$REPO_ROOT" 2>/dev/null) || true

if [[ -z "$FEATURE" ]]; then
    # No active feature — just confirm IIKit is initialized
    echo "IIKit project. Run /iikit-core status to see current state."
    exit 0
fi

STAGE=$(get_feature_stage "$REPO_ROOT" "$FEATURE")

# Build context summary
echo "IIKit active feature: $FEATURE (stage: $STAGE)"

# Get next step from single source of truth
NS_JSON=$(bash "$SCRIPT_DIR/next-step.sh" --phase status --json --project-root "$REPO_ROOT" 2>/dev/null) || NS_JSON='{}'
NS=$(echo "$NS_JSON" | jq -r '.next_step // empty' 2>/dev/null)

if [[ -n "$NS" ]]; then
    echo "Next: $NS"
elif [[ "$STAGE" == "complete" ]]; then
    echo "All tasks complete."
fi
