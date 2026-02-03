#!/usr/bin/env bats
# Tests for check-prerequisites.sh

load 'test_helper'

CHECK_SCRIPT="$SCRIPTS_DIR/check-prerequisites.sh"

setup() {
    setup_test_dir
    # Set SPECIFY_FEATURE to simulate being on a feature
    export SPECIFY_FEATURE="001-test-feature"
    # Ensure we're in TEST_DIR for all tests
    cd "$TEST_DIR"
}

teardown() {
    unset SPECIFY_FEATURE
    teardown_test_dir
}

# =============================================================================
# Paths-only mode tests
# =============================================================================

@test "check-prerequisites: --paths-only returns paths without validation" {
    result=$("$CHECK_SCRIPT" --paths-only)

    assert_contains "$result" "REPO_ROOT:"
    assert_contains "$result" "BRANCH:"
    assert_contains "$result" "FEATURE_DIR:"
}

@test "check-prerequisites: --paths-only --json returns JSON paths" {
    result=$("$CHECK_SCRIPT" --paths-only --json)

    assert_contains "$result" '"REPO_ROOT"'
    assert_contains "$result" '"BRANCH"'
    assert_contains "$result" '"FEATURE_DIR"'
}

@test "check-prerequisites: --paths-only succeeds even without feature dir" {
    run "$CHECK_SCRIPT" --paths-only
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# Validation mode tests
# =============================================================================

@test "check-prerequisites: fails when feature dir missing" {
    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Feature directory not found"
}

@test "check-prerequisites: fails when constitution missing" {
    feature_dir=$(create_mock_feature "001-test-feature")
    rm CONSTITUTION.md

    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Constitution not found"
}

@test "check-prerequisites: fails when spec.md missing" {
    mkdir -p specs/001-test-feature

    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "spec.md not found"
}

@test "check-prerequisites: fails when plan.md missing" {
    mkdir -p specs/001-test-feature
    cp "$FIXTURES_DIR/spec.md" specs/001-test-feature/spec.md

    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "plan.md not found"
}

@test "check-prerequisites: succeeds with spec and plan" {
    create_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# Task requirement tests
# =============================================================================

@test "check-prerequisites: --require-tasks fails without tasks.md" {
    create_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --json --require-tasks
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "tasks.md not found"
}

@test "check-prerequisites: --require-tasks succeeds with tasks.md" {
    create_complete_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --json --require-tasks
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# Available docs tests
# =============================================================================

@test "check-prerequisites: lists available docs in JSON" {
    feature_dir=$(create_mock_feature "001-test-feature")

    # Add some optional docs
    echo "# Research" > "$feature_dir/research.md"
    mkdir -p "$feature_dir/contracts"
    echo "openapi: 3.0.0" > "$feature_dir/contracts/api.yaml"

    result=$("$CHECK_SCRIPT" --json)

    assert_contains "$result" '"AVAILABLE_DOCS"'
    assert_contains "$result" '"research.md"'
    assert_contains "$result" '"contracts/"'
}

@test "check-prerequisites: --include-tasks adds tasks to available docs" {
    create_complete_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --json --include-tasks)

    assert_contains "$result" '"tasks.md"'
}

@test "check-prerequisites: returns empty AVAILABLE_DOCS when no optional docs" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --json)

    # Should have empty array or no optional docs
    [[ "$result" == *'"AVAILABLE_DOCS":[]'* ]] || [[ "$result" != *'"research.md"'* ]]
}

# =============================================================================
# JSON output tests
# =============================================================================

@test "check-prerequisites: JSON output is valid JSON" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --json)

    # jq will fail if invalid JSON
    echo "$result" | jq . >/dev/null
}

@test "check-prerequisites: JSON contains FEATURE_DIR" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --json)

    feature_dir=$(echo "$result" | jq -r '.FEATURE_DIR')
    [[ "$feature_dir" == *"001-test-feature"* ]]
}

# =============================================================================
# Help tests
# =============================================================================

@test "check-prerequisites: --help shows usage" {
    run "$CHECK_SCRIPT" --help
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage:"
    assert_contains "$output" "--json"
    assert_contains "$output" "--require-tasks"
}
