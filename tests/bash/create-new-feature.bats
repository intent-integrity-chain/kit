#!/usr/bin/env bats
# Tests for create-new-feature.sh

load 'test_helper'

CREATE_SCRIPT="$SCRIPTS_DIR/create-new-feature.sh"

setup() {
    setup_test_dir
    # Initialize git for branch creation tests
    git init . >/dev/null 2>&1
    git config user.email "test@test.com"
    git config user.name "Test"
    touch .gitkeep
    git add .gitkeep
    git commit -m "initial" >/dev/null 2>&1
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Basic feature creation tests
# =============================================================================

@test "create-new-feature: creates feature directory" {
    run "$CREATE_SCRIPT" --json "Add user authentication"
    [[ "$status" -eq 0 ]]

    # Should have created a specs/001-* directory
    local dirs=(specs/001-*)
    [[ -d "${dirs[0]}" ]]
}

@test "create-new-feature: creates spec.md from template" {
    run "$CREATE_SCRIPT" --json "Add user authentication"

    spec_file=$(find specs -name "spec.md" | head -1)
    [[ -f "$spec_file" ]]
}

@test "create-new-feature: outputs JSON with required fields" {
    result=$("$CREATE_SCRIPT" --json "Add user authentication")

    assert_contains "$result" '"BRANCH_NAME"'
    assert_contains "$result" '"SPEC_FILE"'
    assert_contains "$result" '"FEATURE_NUM"'
    assert_contains "$result" '"HAS_GIT"'
}

@test "create-new-feature: creates git branch by default" {
    "$CREATE_SCRIPT" --json "Add user authentication"

    branch=$(git branch --show-current)
    [[ "$branch" == 001-* ]]
}

# =============================================================================
# Branch naming tests
# =============================================================================

@test "create-new-feature: generates clean branch name" {
    result=$("$CREATE_SCRIPT" --json "Add user authentication system")

    # Should contain meaningful words, no stop words
    assert_contains "$result" "user"
    assert_contains "$result" "authentication"
}

@test "create-new-feature: uses short-name when provided" {
    result=$("$CREATE_SCRIPT" --json --short-name "user-auth" "Add user authentication")

    assert_contains "$result" "user-auth"
}

@test "create-new-feature: removes stop words from branch name" {
    result=$("$CREATE_SCRIPT" --json "I want to add a new feature for the users")

    # Should not contain common stop words
    assert_not_contains "$result" "-i-"
    assert_not_contains "$result" "-want-"
    assert_not_contains "$result" "-to-"
    assert_not_contains "$result" "-a-"
    assert_not_contains "$result" "-the-"
}

@test "create-new-feature: handles special characters" {
    result=$("$CREATE_SCRIPT" --json "Fix bug #123: user's profile")

    # Should have clean branch name without special chars
    branch_name=$(echo "$result" | jq -r '.BRANCH_NAME')
    [[ "$branch_name" != *"#"* ]]
    [[ "$branch_name" != *"'"* ]]
    [[ "$branch_name" != *":"* ]]
}

# =============================================================================
# Number handling tests
# =============================================================================

@test "create-new-feature: auto-increments feature number" {
    # Create first feature
    "$CREATE_SCRIPT" --json --skip-branch "First feature"

    # Create second feature
    git checkout -b temp-branch >/dev/null 2>&1  # Need to be on different branch
    result=$("$CREATE_SCRIPT" --json --skip-branch "Second feature")

    assert_contains "$result" '"FEATURE_NUM":"002"'
}

@test "create-new-feature: respects --number override" {
    result=$("$CREATE_SCRIPT" --json --number 42 "Custom numbered feature")

    assert_contains "$result" '"FEATURE_NUM":"042"'
}

@test "create-new-feature: pads number to 3 digits" {
    result=$("$CREATE_SCRIPT" --json --number 5 "Padded feature")

    assert_contains "$result" '"FEATURE_NUM":"005"'
}

# =============================================================================
# Skip branch tests
# =============================================================================

@test "create-new-feature: --skip-branch creates directory without branch" {
    original_branch=$(git branch --show-current)

    "$CREATE_SCRIPT" --json --skip-branch "No branch feature"

    current_branch=$(git branch --show-current)
    [[ "$current_branch" == "$original_branch" ]]

    # But directory should still exist
    local dirs=(specs/001-*)
    [[ -d "${dirs[0]}" ]]
}

# =============================================================================
# Non-git repo tests
# =============================================================================

@test "create-new-feature: works in non-git repo" {
    # Remove git
    rm -rf .git

    result=$("$CREATE_SCRIPT" --json "Feature without git")

    local dirs=(specs/001-*)
    [[ -d "${dirs[0]}" ]]
    assert_contains "$result" '"HAS_GIT":false'
}

# =============================================================================
# Branch name length tests
# =============================================================================

@test "create-new-feature: truncates long branch names" {
    # Create a very long description
    long_desc=$(printf 'word%.0s ' {1..100})

    result=$("$CREATE_SCRIPT" --json --skip-branch "$long_desc")

    branch_name=$(echo "$result" | jq -r '.BRANCH_NAME')
    # GitHub limit is 244 bytes
    [[ ${#branch_name} -le 244 ]]
}
