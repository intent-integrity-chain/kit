#!/usr/bin/env bats
# Tests for setup-plan.sh

load 'test_helper'

SETUP_PLAN_SCRIPT="$SCRIPTS_DIR/setup-plan.sh"

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Help and usage tests
# =============================================================================

@test "setup-plan: --help shows usage" {
    run "$SETUP_PLAN_SCRIPT" --help
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage"
    assert_contains "$output" "--json"
}

@test "setup-plan: -h shows usage" {
    run "$SETUP_PLAN_SCRIPT" -h
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage"
}

# =============================================================================
# Prerequisite validation tests
# =============================================================================

@test "setup-plan: fails without constitution" {
    rm -f CONSTITUTION.md
    rm -f .specify/memory/constitution.md

    run "$SETUP_PLAN_SCRIPT"
    [[ "$status" -eq 1 ]]
}

@test "setup-plan: fails without spec.md" {
    # No feature directory with spec.md
    run "$SETUP_PLAN_SCRIPT"
    [[ "$status" -eq 1 ]]
}

@test "setup-plan: succeeds with valid prerequisites" {
    # Create feature with spec
    feature_dir=$(create_mock_feature)

    # Checkout to feature branch
    git checkout -b 001-test-feature >/dev/null 2>&1

    run "$SETUP_PLAN_SCRIPT"
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# Plan template tests
# =============================================================================

@test "setup-plan: creates plan.md from template" {
    feature_dir=$(create_mock_feature)
    rm -f "$TEST_DIR/$feature_dir/plan.md"  # Remove the mock plan

    git checkout -b 001-test-feature >/dev/null 2>&1

    "$SETUP_PLAN_SCRIPT"

    [[ -f "$TEST_DIR/$feature_dir/plan.md" ]]
}

@test "setup-plan: reports spec quality score" {
    feature_dir=$(create_mock_feature)
    git checkout -b 001-test-feature >/dev/null 2>&1

    run "$SETUP_PLAN_SCRIPT"
    assert_contains "$output" "quality"
}

# =============================================================================
# JSON output tests
# =============================================================================

@test "setup-plan: --json outputs valid JSON" {
    feature_dir=$(create_mock_feature)
    git checkout -b 001-test-feature >/dev/null 2>&1

    result=$("$SETUP_PLAN_SCRIPT" --json)

    assert_contains "$result" '"FEATURE_SPEC"'
    assert_contains "$result" '"IMPL_PLAN"'
    assert_contains "$result" '"FEATURE_DIR"'
    assert_contains "$result" '"BRANCH"'
    assert_contains "$result" '"HAS_GIT"'
}

@test "setup-plan: JSON includes correct branch name" {
    feature_dir=$(create_mock_feature)
    git checkout -b 001-test-feature >/dev/null 2>&1

    result=$("$SETUP_PLAN_SCRIPT" --json)

    assert_contains "$result" '001-test-feature'
}

@test "setup-plan: JSON shows HAS_GIT as boolean true" {
    feature_dir=$(create_mock_feature)
    git checkout -b 001-test-feature >/dev/null 2>&1

    result=$("$SETUP_PLAN_SCRIPT" --json)

    # Should be boolean true, not string "true"
    assert_contains "$result" '"HAS_GIT":true'
}

# =============================================================================
# Non-git repo tests
# =============================================================================

@test "setup-plan: works with SPECIFY_FEATURE in non-git context" {
    # Create feature first while git exists
    feature_dir=$(create_mock_feature)

    # Remove git but keep the test directory as repo root fallback
    rm -rf .git

    export SPECIFY_FEATURE="001-test-feature"
    # Script should work by using SPECIFY_FEATURE and --project-root
    run "$SETUP_PLAN_SCRIPT" --project-root "$TEST_DIR"
    unset SPECIFY_FEATURE

    # May warn about non-git but should still run
    [[ "$status" -eq 0 ]] || assert_contains "$output" "Warning"
}

# =============================================================================
# Low quality spec warning tests
# =============================================================================

@test "setup-plan: fails validation on incomplete spec" {
    mkdir -p specs/001-test-feature
    cp "$FIXTURES_DIR/spec-incomplete.md" specs/001-test-feature/spec.md

    git checkout -b 001-test-feature >/dev/null 2>&1

    run "$SETUP_PLAN_SCRIPT"
    # Incomplete spec should fail validation
    [[ "$status" -ne 0 ]]
    assert_contains "$output" "ERROR" || assert_contains "$output" "missing"
}
