#!/usr/bin/env bats
# Tests for session-context-hook-gemini.sh (Gemini JSON protocol)

load 'test_helper'

HOOK_SCRIPT="$SCRIPTS_DIR/session-context-hook-gemini.sh"

setup() {
    setup_test_dir
    cd "$TEST_DIR"
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# JSON output format
# =============================================================================

@test "gemini-hook: outputs valid JSON for non-iikit project" {
    rm -f CONSTITUTION.md
    rm -rf .specify

    result=$("$HOOK_SCRIPT")
    echo "$result" | jq . >/dev/null
    [[ "$result" == "{}" ]]
}

@test "gemini-hook: outputs JSON with additionalContext for active feature" {
    mkdir -p specs/001-test-feature
    echo "# Spec" > specs/001-test-feature/spec.md
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    result=$("$HOOK_SCRIPT")
    echo "$result" | jq . >/dev/null

    context=$(echo "$result" | jq -r '.hookSpecificOutput.additionalContext')
    [[ "$context" == *"001-test-feature"* ]]
    [[ "$context" == *"specified"* ]]
}

@test "gemini-hook: outputs JSON with context for no active feature" {
    result=$("$HOOK_SCRIPT")
    echo "$result" | jq . >/dev/null

    context=$(echo "$result" | jq -r '.hookSpecificOutput.additionalContext')
    [[ "$context" == *"IIKit project"* ]]
}

@test "gemini-hook: includes next step in context" {
    mkdir -p specs/001-test-feature
    echo "# Spec" > specs/001-test-feature/spec.md
    echo "# Plan" > specs/001-test-feature/plan.md
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    result=$("$HOOK_SCRIPT")
    context=$(echo "$result" | jq -r '.hookSpecificOutput.additionalContext')
    [[ "$context" == *"/iikit-05-tasks"* ]]
}

@test "gemini-hook: no plain text on stdout" {
    mkdir -p specs/001-test-feature
    echo "# Spec" > specs/001-test-feature/spec.md
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    result=$("$HOOK_SCRIPT")
    # Every line of stdout must be valid JSON
    while IFS= read -r line; do
        echo "$line" | jq . >/dev/null 2>&1 || {
            echo "Non-JSON output detected: $line" >&2
            return 1
        }
    done <<< "$result"
}
