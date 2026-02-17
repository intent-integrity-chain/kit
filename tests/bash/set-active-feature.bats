#!/usr/bin/env bats
# Tests for set-active-feature.sh

load 'test_helper'

SET_SCRIPT="$SCRIPTS_DIR/set-active-feature.sh"

setup() {
    setup_test_dir
    # Create test features
    mkdir -p "$TEST_DIR/specs/001-user-auth"
    echo "# Spec" > "$TEST_DIR/specs/001-user-auth/spec.md"
    mkdir -p "$TEST_DIR/specs/002-payment-flow"
    echo "# Spec" > "$TEST_DIR/specs/002-payment-flow/spec.md"
    echo "# Plan" > "$TEST_DIR/specs/002-payment-flow/plan.md"
    mkdir -p "$TEST_DIR/specs/003-dashboard"
    echo "# Spec" > "$TEST_DIR/specs/003-dashboard/spec.md"
    printf '%s\n%s\n' '- [ ] T001 Do something' '- [x] T002 Done' > "$TEST_DIR/specs/003-dashboard/tasks.md"
    cd "$TEST_DIR"
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Selection by number
# =============================================================================

@test "set-active-feature: selects by number 1" {
    run "$SET_SCRIPT" --json 1
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "001-user-auth"
}

@test "set-active-feature: selects by padded number 001" {
    run "$SET_SCRIPT" --json 001
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "001-user-auth"
}

@test "set-active-feature: selects by number 2" {
    run "$SET_SCRIPT" --json 2
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "002-payment-flow"
}

# =============================================================================
# Selection by name
# =============================================================================

@test "set-active-feature: selects by full directory name" {
    run "$SET_SCRIPT" --json "001-user-auth"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "001-user-auth"
}

@test "set-active-feature: selects by partial name" {
    run "$SET_SCRIPT" --json "payment"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "002-payment-flow"
}

@test "set-active-feature: selects by partial name dashboard" {
    run "$SET_SCRIPT" --json "dashboard"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "003-dashboard"
}

# =============================================================================
# Error cases
# =============================================================================

@test "set-active-feature: fails for no match" {
    run "$SET_SCRIPT" --json "nonexistent"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "No feature matching"
}

@test "set-active-feature: fails for ambiguous partial" {
    # Both 001-user-auth and 003-dashboard contain 'a'
    # Use a pattern that matches multiple
    mkdir -p "$TEST_DIR/specs/004-user-profile"
    echo "# Spec" > "$TEST_DIR/specs/004-user-profile/spec.md"
    run "$SET_SCRIPT" --json "user"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Ambiguous"
}

@test "set-active-feature: fails with no selector" {
    run "$SET_SCRIPT" --json
    [[ "$status" -eq 1 ]]
}

# =============================================================================
# Sticky persistence
# =============================================================================

@test "set-active-feature: writes active-feature file" {
    run "$SET_SCRIPT" --json 2
    [[ "$status" -eq 0 ]]
    [[ -f "$TEST_DIR/.specify/active-feature" ]]
    result=$(cat "$TEST_DIR/.specify/active-feature")
    [[ "$result" == "002-payment-flow" ]]
}

# =============================================================================
# Stage detection in output
# =============================================================================

@test "set-active-feature: reports stage specified" {
    run "$SET_SCRIPT" --json 1
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "specified"
}

@test "set-active-feature: reports stage planned" {
    run "$SET_SCRIPT" --json 2
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "planned"
}

@test "set-active-feature: reports stage implementing" {
    run "$SET_SCRIPT" --json 3
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "implementing"
}

# =============================================================================
# Text mode
# =============================================================================

@test "set-active-feature: text mode shows feature name" {
    run "$SET_SCRIPT" 1
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Active feature set to: 001-user-auth"
}

# =============================================================================
# Help
# =============================================================================

@test "set-active-feature: --help shows usage" {
    run "$SET_SCRIPT" --help
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage:"
    assert_contains "$output" "SELECTOR"
}
