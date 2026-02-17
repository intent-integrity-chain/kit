#!/usr/bin/env bats
# Tests for session-context-hook.sh

load 'test_helper'

HOOK_SCRIPT="$SCRIPTS_DIR/session-context-hook.sh"

setup() {
    setup_test_dir
    cd "$TEST_DIR"
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Non-IIKit project (silent exit)
# =============================================================================

@test "session-hook: exits silently for non-iikit project" {
    rm -f CONSTITUTION.md
    rm -rf .specify

    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

# =============================================================================
# IIKit project without active feature
# =============================================================================

@test "session-hook: shows generic message when no active feature" {
    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "IIKit project"
    assert_contains "$output" "/iikit-core status"
}

# =============================================================================
# Active feature with stages
# =============================================================================

@test "session-hook: shows specified stage with next steps" {
    mkdir -p specs/001-test-feature
    echo "# Spec" > specs/001-test-feature/spec.md
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "001-test-feature"
    assert_contains "$output" "specified"
    assert_contains "$output" "/iikit-03-plan"
}

@test "session-hook: shows planned stage with next steps" {
    mkdir -p specs/001-test-feature
    echo "# Spec" > specs/001-test-feature/spec.md
    echo "# Plan" > specs/001-test-feature/plan.md
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "planned"
    assert_contains "$output" "/iikit-06-tasks"
}

@test "session-hook: shows tasks-ready stage with next steps" {
    mkdir -p specs/001-test-feature
    printf '%s\n%s\n' '- [ ] T001 Do something' '- [ ] T002 Do another' > specs/001-test-feature/tasks.md
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "tasks-ready"
    assert_contains "$output" "/iikit-08-implement"
}

@test "session-hook: shows implementing stage with resume" {
    mkdir -p specs/001-test-feature
    printf '%s\n%s\n' '- [x] T001 Done' '- [ ] T002 Not done' > specs/001-test-feature/tasks.md
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "implementing"
    assert_contains "$output" "resume"
}

@test "session-hook: shows complete stage" {
    mkdir -p specs/001-test-feature
    printf '%s\n%s\n' '- [x] T001 Done' '- [x] T002 Also done' > specs/001-test-feature/tasks.md
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "complete"
    assert_contains "$output" "/iikit-09-taskstoissues"
}

# =============================================================================
# Invalid active feature (stale file)
# =============================================================================

@test "session-hook: falls back when active-feature points to deleted dir" {
    mkdir -p .specify
    echo "999-deleted-feature" > .specify/active-feature

    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    # read_active_feature validates dir exists, returns empty
    assert_contains "$output" "IIKit project"
}
