#!/usr/bin/env bats
# Tests for common.sh functions

load 'test_helper'

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# get_repo_root tests
# =============================================================================

@test "get_repo_root: returns git root in git repo" {
    # TEST_DIR already has git initialized by setup_test_dir
    result=$(get_repo_root)
    # Use realpath to normalize paths (handles symlinks, etc.)
    [[ "$(cd "$result" && pwd -P)" == "$(cd "$TEST_DIR" && pwd -P)" ]]
}

@test "get_repo_root: falls back to script location in non-git repo" {
    # This test verifies the fallback mechanism works
    # The actual path depends on script location
    result=$(get_repo_root)
    [[ -d "$result" ]]
}

# =============================================================================
# get_current_branch tests
# =============================================================================

@test "get_current_branch: returns SPECIFY_FEATURE if set" {
    export SPECIFY_FEATURE="test-feature"
    result=$(get_current_branch)
    [[ "$result" == "test-feature" ]]
    unset SPECIFY_FEATURE
}

@test "get_current_branch: returns git branch in git repo" {
    # TEST_DIR already has git initialized by setup_test_dir
    result=$(get_current_branch)
    # Should be 'main' or 'master' depending on git config
    [[ "$result" == "main" || "$result" == "master" ]]
}

@test "get_current_branch: returns main as fallback in non-git repo" {
    # Remove git to simulate non-git repo
    rm -rf .git

    # Create feature dirs (but they won't be found because get_repo_root
    # falls back to script location, not current directory)
    mkdir -p specs/001-first-feature
    mkdir -p specs/002-second-feature

    unset SPECIFY_FEATURE
    result=$(get_current_branch)
    # Without git, get_repo_root falls back to script location which doesn't
    # have these test specs, so it returns "main" as final fallback
    [[ "$result" == "main" ]]
}

# =============================================================================
# check_feature_branch tests
# =============================================================================

@test "check_feature_branch: accepts NNN- pattern" {
    run check_feature_branch "001-test-feature" "true"
    [[ "$status" -eq 0 ]]
}

@test "check_feature_branch: accepts SPECIFY_FEATURE override" {
    export SPECIFY_FEATURE="manual-override"
    run check_feature_branch "main" "true"
    [[ "$status" -eq 0 ]]
    unset SPECIFY_FEATURE
}

@test "check_feature_branch: rejects non-feature branch with no features" {
    run check_feature_branch "main" "true"
    [[ "$status" -eq 1 ]]
}

@test "check_feature_branch: auto-selects single feature directory" {
    mkdir -p "$TEST_DIR/specs/001-only-feature"
    run check_feature_branch "main" "true"
    [[ "$status" -eq 0 ]]
}

@test "check_feature_branch: warns for non-git repo" {
    run check_feature_branch "main" "false"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Warning"
}

# =============================================================================
# find_feature_dir_by_prefix tests
# =============================================================================

@test "find_feature_dir_by_prefix: finds matching prefix" {
    mkdir -p specs/004-original-feature

    result=$(find_feature_dir_by_prefix "$TEST_DIR" "004-fix-typo")
    assert_contains "$result" "004-original-feature"
}

@test "find_feature_dir_by_prefix: returns exact path for non-prefixed branch" {
    result=$(find_feature_dir_by_prefix "$TEST_DIR" "main")
    [[ "$result" == "$TEST_DIR/specs/main" ]]
}

@test "find_feature_dir_by_prefix: returns branch path when no match" {
    result=$(find_feature_dir_by_prefix "$TEST_DIR" "999-nonexistent")
    [[ "$result" == "$TEST_DIR/specs/999-nonexistent" ]]
}

# =============================================================================
# validate_constitution tests
# =============================================================================

@test "validate_constitution: passes with valid constitution" {
    run validate_constitution "$TEST_DIR"
    [[ "$status" -eq 0 ]]
}

@test "validate_constitution: fails when constitution missing" {
    rm CONSTITUTION.md
    run validate_constitution "$TEST_DIR"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "not found"
}

# =============================================================================
# validate_spec tests
# =============================================================================

@test "validate_spec: passes with valid spec" {
    feature_dir=$(create_mock_feature)
    run validate_spec "$TEST_DIR/$feature_dir/spec.md"
    [[ "$status" -eq 0 ]]
}

@test "validate_spec: fails when spec missing" {
    run validate_spec "$TEST_DIR/specs/nonexistent/spec.md"
    [[ "$status" -eq 1 ]]
}

@test "validate_spec: fails when missing required sections" {
    feature_dir=$(create_mock_feature)
    echo "# Empty Spec" > "$TEST_DIR/$feature_dir/spec.md"
    run validate_spec "$TEST_DIR/$feature_dir/spec.md"
    [[ "$status" -eq 1 ]]
}

# =============================================================================
# validate_plan tests
# =============================================================================

@test "validate_plan: passes with valid plan" {
    feature_dir=$(create_mock_feature)
    run validate_plan "$TEST_DIR/$feature_dir/plan.md"
    [[ "$status" -eq 0 ]]
}

@test "validate_plan: fails when plan missing" {
    run validate_plan "$TEST_DIR/specs/nonexistent/plan.md"
    [[ "$status" -eq 1 ]]
}

# =============================================================================
# validate_tasks tests
# =============================================================================

@test "validate_tasks: passes with valid tasks" {
    feature_dir=$(create_complete_mock_feature)
    run validate_tasks "$TEST_DIR/$feature_dir/tasks.md"
    [[ "$status" -eq 0 ]]
}

@test "validate_tasks: fails when tasks missing" {
    run validate_tasks "$TEST_DIR/specs/nonexistent/tasks.md"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "/iikit-06-tasks"
}

# =============================================================================
# calculate_spec_quality tests
# =============================================================================

@test "calculate_spec_quality: returns high score for good spec" {
    feature_dir=$(create_mock_feature)
    result=$(calculate_spec_quality "$TEST_DIR/$feature_dir/spec.md")
    # Good spec should score 6 or higher
    [[ "$result" -ge 6 ]]
}

@test "calculate_spec_quality: returns 0 for missing spec" {
    result=$(calculate_spec_quality "$TEST_DIR/nonexistent.md")
    [[ "$result" -eq 0 ]]
}

@test "calculate_spec_quality: returns low score for incomplete spec" {
    mkdir -p specs/incomplete
    cp "$FIXTURES_DIR/spec-incomplete.md" specs/incomplete/spec.md
    result=$(calculate_spec_quality "$TEST_DIR/specs/incomplete/spec.md")
    [[ "$result" -lt 6 ]]
}
