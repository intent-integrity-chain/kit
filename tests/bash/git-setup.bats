#!/usr/bin/env bats
# Tests for git-setup.sh

load 'test_helper'

GIT_SETUP_SCRIPT="$SCRIPTS_DIR/git-setup.sh"

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    # Configure git identity for CI environments
    git config --global user.email "test@test.com" 2>/dev/null || true
    git config --global user.name "Test" 2>/dev/null || true
}

teardown() {
    cd /
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# =============================================================================
# Help and usage tests
# =============================================================================

@test "git-setup: --help shows usage" {
    run "$GIT_SETUP_SCRIPT" --help
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage"
    assert_contains "$output" "--json"
}

@test "git-setup: -h shows usage" {
    run "$GIT_SETUP_SCRIPT" -h
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage"
}

@test "git-setup: rejects unknown flags" {
    run "$GIT_SETUP_SCRIPT" --unknown-flag
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Unknown option"
}

# =============================================================================
# Non-repo detection
# =============================================================================

@test "git-setup: detects non-repo directory (JSON)" {
    # TEST_DIR is not a git repo
    result=$("$GIT_SETUP_SCRIPT" --json)
    assert_contains "$result" '"is_git_repo":false'
    assert_contains "$result" '"has_remote":false'
    assert_contains "$result" '"remote_url":""'
}

@test "git-setup: detects non-repo directory (plain text)" {
    run "$GIT_SETUP_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Is git repo:         false"
    assert_contains "$output" "Has remote:          false"
}

# =============================================================================
# Repo without remote
# =============================================================================

@test "git-setup: detects repo without remote (JSON)" {
    git init . >/dev/null 2>&1

    result=$("$GIT_SETUP_SCRIPT" --json)
    assert_contains "$result" '"is_git_repo":true'
    assert_contains "$result" '"has_remote":false'
    assert_contains "$result" '"remote_url":""'
    assert_contains "$result" '"is_github_remote":false'
}

# =============================================================================
# Repo with GitHub remote
# =============================================================================

@test "git-setup: detects GitHub remote (JSON)" {
    git init . >/dev/null 2>&1
    git remote add origin https://github.com/example/repo.git

    result=$("$GIT_SETUP_SCRIPT" --json)
    assert_contains "$result" '"is_git_repo":true'
    assert_contains "$result" '"has_remote":true'
    assert_contains "$result" '"remote_url":"https://github.com/example/repo.git"'
    assert_contains "$result" '"is_github_remote":true'
}

@test "git-setup: detects GitHub SSH remote" {
    git init . >/dev/null 2>&1
    git remote add origin git@github.com:example/repo.git

    result=$("$GIT_SETUP_SCRIPT" --json)
    assert_contains "$result" '"has_remote":true'
    assert_contains "$result" '"is_github_remote":true'
}

# =============================================================================
# Non-GitHub remote
# =============================================================================

@test "git-setup: detects non-GitHub remote (JSON)" {
    git init . >/dev/null 2>&1
    git remote add origin https://gitlab.com/example/repo.git

    result=$("$GIT_SETUP_SCRIPT" --json)
    assert_contains "$result" '"has_remote":true'
    assert_contains "$result" '"is_github_remote":false'
    assert_contains "$result" '"remote_url":"https://gitlab.com/example/repo.git"'
}

# =============================================================================
# IIKit artifact detection
# =============================================================================

@test "git-setup: detects IIKit artifacts when .specify exists" {
    mkdir -p .specify

    result=$("$GIT_SETUP_SCRIPT" --json)
    assert_contains "$result" '"has_iikit_artifacts":true'
}

@test "git-setup: detects IIKit artifacts when CONSTITUTION.md exists" {
    echo "# Constitution" > CONSTITUTION.md

    result=$("$GIT_SETUP_SCRIPT" --json)
    assert_contains "$result" '"has_iikit_artifacts":true'
}

@test "git-setup: no IIKit artifacts in empty directory" {
    result=$("$GIT_SETUP_SCRIPT" --json)
    assert_contains "$result" '"has_iikit_artifacts":false'
}

# =============================================================================
# Git available field
# =============================================================================

@test "git-setup: reports git_available true when git is installed" {
    result=$("$GIT_SETUP_SCRIPT" --json)
    assert_contains "$result" '"git_available":true'
}

# =============================================================================
# gh CLI detection
# =============================================================================

@test "git-setup: reports gh_available field" {
    result=$("$GIT_SETUP_SCRIPT" --json)
    # gh may or may not be installed; just verify the field exists
    assert_contains "$result" '"gh_available":'
}

@test "git-setup: reports gh_authenticated field" {
    result=$("$GIT_SETUP_SCRIPT" --json)
    assert_contains "$result" '"gh_authenticated":'
}

# =============================================================================
# Plain text output
# =============================================================================

@test "git-setup: plain text output shows all fields" {
    git init . >/dev/null 2>&1

    run "$GIT_SETUP_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Git available:"
    assert_contains "$output" "Is git repo:"
    assert_contains "$output" "Has remote:"
    assert_contains "$output" "Remote URL:"
    assert_contains "$output" "Is GitHub remote:"
    assert_contains "$output" "gh CLI available:"
    assert_contains "$output" "gh authenticated:"
    assert_contains "$output" "Has IIKit artifacts:"
}

@test "git-setup: plain text shows (none) for empty remote URL" {
    run "$GIT_SETUP_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Remote URL:          (none)"
}
