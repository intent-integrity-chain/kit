#!/bin/bash
# PreToolUse hook: block git commit --no-verify and other hook bypass attempts.
# Returns JSON with permissionDecision: "deny" when bypass is detected.
# Exit 0 = decision provided; the harness evaluates the JSON.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ "$TOOL" != "Bash" ]] || [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Check for --no-verify or -n flag on git commit
# Strip quoted message content (-m "..." or heredoc) before checking flags
# to avoid false positives when the commit message mentions --no-verify
if echo "$COMMAND" | grep -qE '\bgit\s+commit\b'; then
    # Extract just the git commit invocation line, strip -m message content
    GIT_ARGS=$(echo "$COMMAND" | head -1 | sed 's/-m "[^"]*"//g' | sed "s/-m '[^']*'//g")
    if echo "$GIT_ARGS" | grep -qE '(--no-verify|\s-[a-zA-Z]*n\b)'; then
        echo '{"decision":"block","reason":"git commit --no-verify is prohibited. Fix the pre-commit hook failure instead of bypassing it. Re-run /iikit-04-testify if assertion hashes are stale."}'
        exit 2
    fi
fi

# Check for hook file deletion/modification
if echo "$COMMAND" | grep -qE '(rm|mv|chmod|truncate|>)\s+.*\.git/hooks/'; then
    echo '{"decision":"block","reason":"Modifying .git/hooks/ is prohibited. Pre-commit hooks are an integrity gate."}'
    exit 2
fi

# Check for git plumbing bypass
if echo "$COMMAND" | grep -qE '\bgit\s+(commit-tree|mktree|hash-object\s+.*-w)\b'; then
    echo '{"decision":"block","reason":"Git plumbing commands that bypass hooks are prohibited."}'
    exit 2
fi

exit 0
