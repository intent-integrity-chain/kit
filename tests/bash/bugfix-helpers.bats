#!/usr/bin/env bats
# Tests for bugfix-helpers.sh

load 'test_helper'

BUGFIX_SCRIPT="$REPO_ROOT/tiles/intent-integrity-kit/skills/iikit-core/scripts/bash/bugfix-helpers.sh"

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# --list-features tests (TS-020)
# =============================================================================

@test "list-features: returns empty array with no features" {
    result=$("$BUGFIX_SCRIPT" --list-features)
    [[ "$result" == "[]" ]]
}

@test "list-features: returns JSON array with features and stages" {
    mkdir -p "$TEST_DIR/specs/001-feature-a"
    echo "# Spec" > "$TEST_DIR/specs/001-feature-a/spec.md"
    mkdir -p "$TEST_DIR/specs/002-feature-b"
    echo "# Spec" > "$TEST_DIR/specs/002-feature-b/spec.md"
    echo "# Plan" > "$TEST_DIR/specs/002-feature-b/plan.md"

    result=$("$BUGFIX_SCRIPT" --list-features)
    assert_contains "$result" "001-feature-a"
    assert_contains "$result" "002-feature-b"
    assert_contains "$result" "specified"
    assert_contains "$result" "planned"
}

# =============================================================================
# --next-bug-id tests (TS-021, TS-022)
# =============================================================================

@test "next-bug-id: returns BUG-001 when no bugs.md exists" {
    mkdir -p "$TEST_DIR/specs/001-test"

    result=$("$BUGFIX_SCRIPT" --next-bug-id "$TEST_DIR/specs/001-test")
    [[ "$result" == "BUG-001" ]]
}

@test "next-bug-id: returns BUG-003 when bugs.md has BUG-001 and BUG-002" {
    mkdir -p "$TEST_DIR/specs/001-test"
    cat > "$TEST_DIR/specs/001-test/bugs.md" <<'EOF'
# Bug Reports: test

## BUG-001

**Description**: First bug

## BUG-002

**Description**: Second bug
EOF

    result=$("$BUGFIX_SCRIPT" --next-bug-id "$TEST_DIR/specs/001-test")
    [[ "$result" == "BUG-003" ]]
}

@test "next-bug-id: handles single bug correctly" {
    mkdir -p "$TEST_DIR/specs/001-test"
    cat > "$TEST_DIR/specs/001-test/bugs.md" <<'EOF'
# Bug Reports: test

## BUG-001

**Description**: Only bug
EOF

    result=$("$BUGFIX_SCRIPT" --next-bug-id "$TEST_DIR/specs/001-test")
    [[ "$result" == "BUG-002" ]]
}

# =============================================================================
# --next-task-ids tests (TS-023)
# =============================================================================

@test "next-task-ids: returns T-B001 when no existing T-B tasks" {
    mkdir -p "$TEST_DIR/specs/001-test"
    cat > "$TEST_DIR/specs/001-test/tasks.md" <<'EOF'
# Tasks
- [ ] T001 Normal task
- [ ] T002 Another task
EOF

    result=$("$BUGFIX_SCRIPT" --next-task-ids "$TEST_DIR/specs/001-test" 3)
    assert_contains "$result" '"start":"T-B001"'
    assert_contains "$result" '"T-B001"'
    assert_contains "$result" '"T-B002"'
    assert_contains "$result" '"T-B003"'
}

@test "next-task-ids: avoids collision with existing T-B tasks" {
    mkdir -p "$TEST_DIR/specs/001-test"
    cat > "$TEST_DIR/specs/001-test/tasks.md" <<'EOF'
# Tasks
- [x] T-B001 Investigate root cause for BUG-001
- [x] T-B002 Implement fix for BUG-001
- [x] T-B003 Write regression test for BUG-001
EOF

    result=$("$BUGFIX_SCRIPT" --next-task-ids "$TEST_DIR/specs/001-test" 3)
    assert_contains "$result" '"start":"T-B004"'
    assert_contains "$result" '"T-B004"'
    assert_contains "$result" '"T-B005"'
    assert_contains "$result" '"T-B006"'
}

@test "next-task-ids: returns T-B001 when no tasks.md exists" {
    mkdir -p "$TEST_DIR/specs/001-test"

    result=$("$BUGFIX_SCRIPT" --next-task-ids "$TEST_DIR/specs/001-test" 2)
    assert_contains "$result" '"start":"T-B001"'
    assert_contains "$result" '"T-B001"'
    assert_contains "$result" '"T-B002"'
}

# =============================================================================
# --validate-feature tests (TS-024)
# =============================================================================

@test "validate-feature: passes when spec.md exists" {
    feature_dir=$(create_mock_feature)

    result=$("$BUGFIX_SCRIPT" --validate-feature "$TEST_DIR/$feature_dir")
    assert_contains "$result" '"valid":true'
}

@test "validate-feature: fails when directory does not exist" {
    run "$BUGFIX_SCRIPT" --validate-feature "$TEST_DIR/specs/nonexistent"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" '"valid":false'
    assert_contains "$output" "not found"
}

@test "validate-feature: fails when spec.md missing" {
    mkdir -p "$TEST_DIR/specs/001-no-spec"

    run "$BUGFIX_SCRIPT" --validate-feature "$TEST_DIR/specs/001-no-spec"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" '"valid":false'
    assert_contains "$output" "spec.md not found"
}

@test "validate-feature: reports artifact presence" {
    feature_dir=$(create_complete_mock_feature)

    result=$("$BUGFIX_SCRIPT" --validate-feature "$TEST_DIR/$feature_dir")
    assert_contains "$result" '"valid":true'
    assert_contains "$result" '"has_tasks":true'
    assert_contains "$result" '"has_tests":true'
}

# =============================================================================
# Error handling tests
# =============================================================================

@test "no arguments shows usage" {
    run "$BUGFIX_SCRIPT"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Usage"
}

@test "unknown subcommand shows error" {
    run "$BUGFIX_SCRIPT" --unknown
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Unknown subcommand"
}
