#!/usr/bin/env bash
# PreToolUse hook: block git commit hook bypass attempts.
# Exit 2 with stderr message = block the tool call.
# Exit 0 = allow (no opinion).

set -uo pipefail

# If jq is not available, allow the call (don't block all Bash calls)
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0

if [[ "$TOOL" != "Bash" ]] || [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Check for --no-verify or -n flag on git commit
# Extract first line only (avoids matching inside heredoc commit messages)
# Strip -m "..." content to avoid false positives on message text
if echo "$COMMAND" | grep -qE 'git[[:space:]]+commit'; then
    GIT_ARGS=$(echo "$COMMAND" | head -1 | sed 's/-m "[^"]*"//g' | sed "s/-m '[^']*'//g")
    if echo "$GIT_ARGS" | grep -qE '(--no-verify|[[:space:]]-[a-zA-Z]*n([[:space:]]|$))'; then
        echo "git commit with hook bypass is prohibited. Fix the pre-commit hook failure instead. Re-run /iikit-04-testify if assertion hashes are stale." >&2
        exit 2
    fi
fi

# Check for hook file deletion/modification
if echo "$COMMAND" | grep -qE '(rm|mv|chmod|truncate|>)[[:space:]].*\.git/hooks'; then
    echo "Modifying .git/hooks is prohibited. Pre-commit hooks are an integrity gate." >&2
    exit 2
fi

# Check for git plumbing bypass
if echo "$COMMAND" | grep -qE 'git[[:space:]]+(commit-tree|mktree|hash-object[[:space:]].*-w)'; then
    echo "Git plumbing commands that bypass hooks are prohibited." >&2
    exit 2
fi

exit 0
