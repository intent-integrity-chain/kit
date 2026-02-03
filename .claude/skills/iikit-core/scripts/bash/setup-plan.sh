#!/usr/bin/env bash

set -e

# Parse command line arguments
JSON_MODE=false
ARGS=()

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --help|-h)
            echo "Usage: $0 [--json]"
            echo "  --json    Output results in JSON format"
            echo "  --help    Show this help message"
            exit 0
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

# Get script directory and load common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Check if we're on a proper feature branch FIRST (may set SPECIFY_FEATURE)
# This must happen before get_feature_paths so it uses the corrected feature name
REPO_ROOT=$(get_repo_root)
HAS_GIT="false"
has_git && HAS_GIT="true"
CURRENT_BRANCH=$(get_current_branch)
check_feature_branch "$CURRENT_BRANCH" "$HAS_GIT" || exit 1

# Now get all paths (will use SPECIFY_FEATURE if it was set by check_feature_branch)
eval $(get_feature_paths)

# VALIDATION: Check constitution exists
validate_constitution "$REPO_ROOT" || exit 1

# VALIDATION: Check spec.md exists and has required structure
validate_spec "$FEATURE_SPEC" || exit 1

# Report spec quality score
SPEC_QUALITY=$(calculate_spec_quality "$FEATURE_SPEC")
echo "Spec quality score: $SPEC_QUALITY/10"
if [[ $SPEC_QUALITY -lt 6 ]]; then
    echo "WARNING: Spec quality is low. Consider running /iikit-02-clarify." >&2
fi

# Ensure the feature directory exists
mkdir -p "$FEATURE_DIR"

# Copy plan template if it exists
# Template path relative to script location (works for both .tessl and .claude installs)
TEMPLATE="$SCRIPT_DIR/../../templates/plan-template.md"
if [[ -f "$TEMPLATE" ]]; then
    cp "$TEMPLATE" "$IMPL_PLAN"
    echo "Copied plan template to $IMPL_PLAN"
else
    echo "Warning: Plan template not found at $TEMPLATE"
    touch "$IMPL_PLAN"
fi

# Output results
if $JSON_MODE; then
    # Output HAS_GIT as proper JSON boolean (no quotes)
    printf '{"FEATURE_SPEC":"%s","IMPL_PLAN":"%s","FEATURE_DIR":"%s","BRANCH":"%s","HAS_GIT":%s}\n' \
        "$FEATURE_SPEC" "$IMPL_PLAN" "$FEATURE_DIR" "$CURRENT_BRANCH" "$HAS_GIT"
else
    echo "FEATURE_SPEC: $FEATURE_SPEC"
    echo "IMPL_PLAN: $IMPL_PLAN"
    echo "FEATURE_DIR: $FEATURE_DIR"
    echo "BRANCH: $CURRENT_BRANCH"
    echo "HAS_GIT: $HAS_GIT"
fi
