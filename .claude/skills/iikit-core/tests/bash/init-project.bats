#!/usr/bin/env bats
# Tests for init-project.sh

load 'test_helper'

INIT_SCRIPT="$SCRIPTS_DIR/init-project.sh"

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    # Configure git identity for CI environments that lack ~/.gitconfig
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

@test "init-project: --help shows usage" {
    run "$INIT_SCRIPT" --help
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage"
    assert_contains "$output" "--json"
    assert_contains "$output" "--commit-constitution"
}

@test "init-project: -h shows usage" {
    run "$INIT_SCRIPT" -h
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage"
}

# =============================================================================
# Validation tests
# =============================================================================

@test "init-project: fails without .specify directory" {
    run "$INIT_SCRIPT"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Not a intent-integrity-kit project"
}

@test "init-project: fails with JSON output without .specify" {
    run "$INIT_SCRIPT" --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" '"success":false'
    assert_contains "$output" '"error"'
}

# =============================================================================
# Git initialization tests
# =============================================================================

@test "init-project: initializes git in new project" {
    mkdir -p .specify

    run "$INIT_SCRIPT"
    [[ "$status" -eq 0 ]]
    [[ -d ".git" ]]
}

@test "init-project: reports already initialized for existing git repo" {
    mkdir -p .specify
    git init . >/dev/null 2>&1

    run "$INIT_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "already exists"
}

@test "init-project: JSON output shows git_initialized true for new repo" {
    mkdir -p .specify

    result=$("$INIT_SCRIPT" --json)
    assert_contains "$result" '"success":true'
    assert_contains "$result" '"git_initialized":true'
    assert_contains "$result" '"git_status":"initialized"'
}

@test "init-project: JSON output shows git_initialized false for existing repo" {
    mkdir -p .specify
    git init . >/dev/null 2>&1

    result=$("$INIT_SCRIPT" --json)
    assert_contains "$result" '"success":true'
    assert_contains "$result" '"git_initialized":false'
    assert_contains "$result" '"git_status":"already_initialized"'
}

# =============================================================================
# Constitution commit tests
# =============================================================================

@test "init-project: --commit-constitution commits constitution file" {
    mkdir -p .specify
    echo "# Constitution" > CONSTITUTION.md

    "$INIT_SCRIPT" --commit-constitution

    # Verify commit was made
    run git log --oneline -1
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "constitution"
}

@test "init-project: --commit-constitution also commits README if exists" {
    mkdir -p .specify
    echo "# Constitution" > CONSTITUTION.md
    echo "# README" > README.md

    "$INIT_SCRIPT" --commit-constitution

    # Verify both files are in git
    run git ls-files
    assert_contains "$output" "CONSTITUTION.md"
    assert_contains "$output" "README.md"
}

@test "init-project: JSON shows constitution_committed true" {
    mkdir -p .specify
    echo "# Constitution" > CONSTITUTION.md

    result=$("$INIT_SCRIPT" --json --commit-constitution)
    assert_contains "$result" '"constitution_committed":true'
}

@test "init-project: JSON shows constitution_committed false when no constitution" {
    mkdir -p .specify

    result=$("$INIT_SCRIPT" --json --commit-constitution)
    assert_contains "$result" '"constitution_committed":false'
}

# =============================================================================
# Error handling tests
# =============================================================================

@test "init-project: rejects unknown options" {
    mkdir -p .specify

    run "$INIT_SCRIPT" --unknown-option
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Unknown option"
}
