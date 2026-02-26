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
# Active feature with stages — next-step.sh artifact-state fallback
# =============================================================================

@test "session-hook: shows specified stage with next steps" {
    mkdir -p specs/001-test-feature
    cp "$FIXTURES_DIR/spec.md" specs/001-test-feature/spec.md
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "001-test-feature"
    assert_contains "$output" "specified"
    assert_contains "$output" "/iikit-02-plan"
}

@test "session-hook: shows planned stage with next steps" {
    create_mock_feature "001-test-feature"
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "planned"
    # TDD mandatory (fixture constitution) with .feature files → /iikit-05-tasks
    assert_contains "$output" "/iikit-05-tasks"
}

@test "session-hook: shows tasks-ready stage with next steps" {
    create_complete_mock_feature "001-test-feature"
    # Overwrite tasks to be all incomplete
    printf '%s\n%s\n' '- [ ] T001 Do something' '- [ ] T002 Do another' > "$TEST_DIR/specs/001-test-feature/tasks.md"
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "tasks-ready"
    assert_contains "$output" "/iikit-07-implement"
}

@test "session-hook: shows implementing stage" {
    create_complete_mock_feature "001-test-feature"
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "implementing"
    assert_contains "$output" "/iikit-07-implement"
}

@test "session-hook: shows complete stage" {
    create_mock_feature "001-test-feature"
    printf '%s\n%s\n' '- [x] T001 Done' '- [x] T002 Also done' > "$TEST_DIR/specs/001-test-feature/tasks.md"
    mkdir -p .specify
    echo "001-test-feature" > .specify/active-feature

    run "$HOOK_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "complete"
    assert_contains "$output" "All tasks complete"
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
