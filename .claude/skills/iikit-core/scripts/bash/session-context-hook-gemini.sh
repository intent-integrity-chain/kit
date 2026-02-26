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

    # Get next step from single source of truth
    local ns_json
    ns_json=$(bash "$SCRIPT_DIR/next-step.sh" --phase status --json --project-root "$repo_root" 2>/dev/null) || ns_json='{}'
    local ns
    ns=$(echo "$ns_json" | jq -r '.next_step // empty' 2>/dev/null)

    if [[ -n "$ns" ]]; then
        context="$context. Next: $ns"
    elif [[ "$stage" == "complete" ]]; then
        context="$context. All tasks complete."
    fi

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
