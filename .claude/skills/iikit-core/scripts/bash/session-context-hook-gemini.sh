#!/usr/bin/env bash
# Gemini CLI SessionStart hook: restore IIKit feature context after /clear
#
# Gemini hooks receive JSON on stdin and must output JSON on stdout.
# All debug output goes to stderr. Plain text stdout will break the hook.

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Build the context string (same logic as session-context-hook.sh)
build_context() {
    local repo_root
    repo_root=$(get_repo_root 2>/dev/null) || return

    # Check if this is an IIKit project
    if [[ ! -f "$repo_root/CONSTITUTION.md" ]] && [[ ! -d "$repo_root/.specify" ]]; then
        return
    fi

    local feature
    feature=$(read_active_feature "$repo_root" 2>/dev/null) || true

    if [[ -z "$feature" ]]; then
        echo "IIKit project. Run /iikit-core status to see current state."
        return
    fi

    local stage
    stage=$(get_feature_stage "$repo_root" "$feature")

    local context="IIKit active feature: $feature (stage: $stage)"

    case "$stage" in
        specified)     context="$context. Next: /iikit-02-clarify or /iikit-03-plan" ;;
        planned)       context="$context. Next: /iikit-04-checklist or /iikit-06-tasks" ;;
        tasks-ready)   context="$context. Next: /iikit-07-analyze or /iikit-08-implement" ;;
        implementing*) context="$context. Next: /iikit-08-implement (resume)" ;;
        complete)      context="$context. All tasks complete. /iikit-09-taskstoissues to export." ;;
    esac

    echo "$context"
}

CONTEXT=$(build_context 2>/dev/null)

if [[ -n "$CONTEXT" ]]; then
    # Gemini expects JSON with hookSpecificOutput.additionalContext
    printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$CONTEXT"
else
    # Empty response — no context to inject
    printf '{}\n'
fi
