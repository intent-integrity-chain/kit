#!/usr/bin/env bash
# Bugfix helper functions for the iikit-bugfix skill
# Provides: --list-features, --next-bug-id, --next-task-ids, --validate-feature

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# SUBCOMMANDS
# =============================================================================

# List all features with stages as JSON array
# Reuses list_features_json() from common.sh
cmd_list_features() {
    list_features_json
}

# Get the next sequential BUG-NNN ID for a feature
# Usage: cmd_next_bug_id <feature_dir>
cmd_next_bug_id() {
    local feature_dir="$1"
    local bugs_file="$feature_dir/bugs.md"

    if [[ ! -f "$bugs_file" ]]; then
        echo "BUG-001"
        return 0
    fi

    local max_id=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^##[[:space:]]+BUG-([0-9]+) ]]; then
            local num="${BASH_REMATCH[1]}"
            num=$((10#$num))
            if [[ "$num" -gt "$max_id" ]]; then
                max_id=$num
            fi
        fi
    done < "$bugs_file"

    local next=$((max_id + 1))
    printf 'BUG-%03d\n' "$next"
}

# Get the next sequential T-BNNN task IDs for a feature
# Usage: cmd_next_task_ids <feature_dir> <count>
cmd_next_task_ids() {
    local feature_dir="$1"
    local count="${2:-3}"
    local tasks_file="$feature_dir/tasks.md"

    local max_id=0

    if [[ -f "$tasks_file" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ T-B([0-9]+) ]]; then
                local num="${BASH_REMATCH[1]}"
                num=$((10#$num))
                if [[ "$num" -gt "$max_id" ]]; then
                    max_id=$num
                fi
            fi
        done < "$tasks_file"
    fi

    local start=$((max_id + 1))
    local ids=""
    for ((i = 0; i < count; i++)); do
        local id=$((start + i))
        if [[ -n "$ids" ]]; then
            ids="$ids,"
        fi
        ids="${ids}$(printf 'T-B%03d' "$id")"
    done

    printf '{"start":"T-B%03d","ids":[' "$start"
    local first=true
    for ((i = 0; i < count; i++)); do
        local id=$((start + i))
        if $first; then
            first=false
        else
            printf ','
        fi
        printf '"T-B%03d"' "$id"
    done
    printf ']}\n'
}

# Validate that a feature directory exists and has spec.md
# Usage: cmd_validate_feature <feature_dir>
cmd_validate_feature() {
    local feature_dir="$1"

    if [[ ! -d "$feature_dir" ]]; then
        printf '{"valid":false,"error":"Feature directory not found: %s"}\n' "$feature_dir"
        return 1
    fi

    if [[ ! -f "$feature_dir/spec.md" ]]; then
        printf '{"valid":false,"error":"spec.md not found in %s. Run /iikit-01-specify first."}\n' "$feature_dir"
        return 1
    fi

    # Report available artifacts
    local has_tasks="false"
    local has_bugs="false"
    local has_tests="false"

    [[ -f "$feature_dir/tasks.md" ]] && has_tasks="true"
    [[ -f "$feature_dir/bugs.md" ]] && has_bugs="true"
    [[ -f "$feature_dir/tests/test-specs.md" ]] && has_tests="true"

    printf '{"valid":true,"has_tasks":%s,"has_bugs":%s,"has_tests":%s}\n' \
        "$has_tasks" "$has_bugs" "$has_tests"
    return 0
}

# =============================================================================
# MAIN DISPATCHER
# =============================================================================

if [[ $# -lt 1 ]]; then
    echo "Usage: bugfix-helpers.sh <subcommand> [args...]" >&2
    echo "Subcommands: --list-features, --next-bug-id, --next-task-ids, --validate-feature" >&2
    exit 1
fi

case "$1" in
    --list-features)
        cmd_list_features
        ;;
    --next-bug-id)
        if [[ $# -lt 2 ]]; then
            echo "Usage: bugfix-helpers.sh --next-bug-id <feature_dir>" >&2
            exit 1
        fi
        cmd_next_bug_id "$2"
        ;;
    --next-task-ids)
        if [[ $# -lt 2 ]]; then
            echo "Usage: bugfix-helpers.sh --next-task-ids <feature_dir> [count]" >&2
            exit 1
        fi
        cmd_next_task_ids "$2" "${3:-3}"
        ;;
    --validate-feature)
        if [[ $# -lt 2 ]]; then
            echo "Usage: bugfix-helpers.sh --validate-feature <feature_dir>" >&2
            exit 1
        fi
        cmd_validate_feature "$2"
        ;;
    *)
        echo "Unknown subcommand: $1" >&2
        echo "Available: --list-features, --next-bug-id, --next-task-ids, --validate-feature" >&2
        exit 1
        ;;
esac
