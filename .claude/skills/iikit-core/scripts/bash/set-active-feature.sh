#!/usr/bin/env bash

# Set the active feature for the current project
#
# Usage: ./set-active-feature.sh [OPTIONS] <selector>
#
# SELECTOR:
#   Number:       1, 001, 3
#   Partial name: user-auth, bugfix
#   Full dir:     001-user-auth
#
# OPTIONS:
#   --json     Output in JSON format
#   --help,-h  Show help message

set -e

JSON_MODE=false
SELECTOR=""

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --help|-h)
            cat << 'EOF'
Usage: set-active-feature.sh [OPTIONS] <selector>

Set the active feature for the current project.

SELECTOR:
  Number:       1, 001, 3
  Partial name: user-auth, bugfix
  Full dir:     001-user-auth

OPTIONS:
  --json     Output in JSON format
  --help,-h  Show this help message

EXAMPLES:
  ./set-active-feature.sh 1
  ./set-active-feature.sh user-auth
  ./set-active-feature.sh --json 001-user-auth

EOF
            exit 0
            ;;
        *)
            SELECTOR="$arg"
            ;;
    esac
done

if [[ -z "$SELECTOR" ]]; then
    echo "ERROR: No feature selector provided. Use --help for usage." >&2
    exit 1
fi

# Source common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO_ROOT=$(get_repo_root)
SPECS_DIR="$REPO_ROOT/specs"

if [[ ! -d "$SPECS_DIR" ]]; then
    echo "ERROR: No specs/ directory found. Run /iikit-01-specify first." >&2
    exit 1
fi

# Collect all feature directories
features=()
for dir in "$SPECS_DIR"/*; do
    if [[ -d "$dir" ]] && [[ "$(basename "$dir")" =~ ^[0-9]{3}- ]]; then
        features+=("$(basename "$dir")")
    fi
done

if [[ ${#features[@]} -eq 0 ]]; then
    echo "ERROR: No feature directories found in specs/." >&2
    exit 1
fi

# Match selector against features
matches=()

# Try matching as a number (e.g., 1 -> 001, 001 -> 001)
if [[ "$SELECTOR" =~ ^[0-9]+$ ]]; then
    local_prefix=$(printf "%03d" "$((10#$SELECTOR))")
    for f in "${features[@]}"; do
        if [[ "$f" =~ ^${local_prefix}- ]]; then
            matches+=("$f")
        fi
    done
fi

# If no match by number, try exact directory name
if [[ ${#matches[@]} -eq 0 ]]; then
    for f in "${features[@]}"; do
        if [[ "$f" == "$SELECTOR" ]]; then
            matches=("$f")
            break
        fi
    done
fi

# If still no match, try partial name match
if [[ ${#matches[@]} -eq 0 ]]; then
    for f in "${features[@]}"; do
        if [[ "$f" == *"$SELECTOR"* ]]; then
            matches+=("$f")
        fi
    done
fi

# Handle results
if [[ ${#matches[@]} -eq 0 ]]; then
    echo "ERROR: No feature matching '$SELECTOR' found." >&2
    echo "Available features:" >&2
    for f in "${features[@]}"; do
        echo "  - $f" >&2
    done
    exit 1
elif [[ ${#matches[@]} -gt 1 ]]; then
    echo "ERROR: Ambiguous selector '$SELECTOR' matches multiple features:" >&2
    for f in "${matches[@]}"; do
        echo "  - $f" >&2
    done
    echo "Be more specific." >&2
    exit 1
fi

# Exactly one match
FEATURE="${matches[0]}"
write_active_feature "$FEATURE"
export SPECIFY_FEATURE="$FEATURE"

STAGE=$(get_feature_stage "$REPO_ROOT" "$FEATURE")

if $JSON_MODE; then
    printf '{"active_feature":"%s","stage":"%s"}\n' "$FEATURE" "$STAGE"
else
    echo "Active feature set to: $FEATURE"
    echo "Stage: $STAGE"
fi
