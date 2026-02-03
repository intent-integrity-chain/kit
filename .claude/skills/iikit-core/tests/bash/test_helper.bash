#!/usr/bin/env bash
# Test helper functions for bats tests

# Get the directory of this helper script
HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$HELPER_DIR")"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")/scripts/bash"
FIXTURES_DIR="$TESTS_DIR/fixtures"

# Source common functions
source "$SCRIPTS_DIR/common.sh"

# Create a temporary test directory
setup_test_dir() {
    TEST_DIR=$(mktemp -d)

    # Initialize git so this directory is its own repo root
    # This prevents git from walking up to find the parent repo
    git -C "$TEST_DIR" init . >/dev/null 2>&1
    git -C "$TEST_DIR" config user.email "test@test.com"
    git -C "$TEST_DIR" config user.name "Test"

    # Create basic structure
    mkdir -p "$TEST_DIR/.specify/memory"
    mkdir -p "$TEST_DIR/specs"
    mkdir -p "$TEST_DIR/.claude/skills/iikit-core/templates"

    # Copy fixtures
    cp "$FIXTURES_DIR/constitution.md" "$TEST_DIR/.specify/memory/constitution.md"

    # Initial commit so git commands work properly
    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit -m "test setup" >/dev/null 2>&1

    # Change to test directory - this is the key step for bats tests
    cd "$TEST_DIR"

    export TEST_DIR
}

# Clean up temporary test directory
teardown_test_dir() {
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Create a mock feature directory
# Returns the relative path (specs/feature-name) for use in assertions
create_mock_feature() {
    local feature_name="${1:-001-test-feature}"
    local feature_dir="$TEST_DIR/specs/$feature_name"

    mkdir -p "$feature_dir"
    cp "$FIXTURES_DIR/spec.md" "$feature_dir/spec.md"
    cp "$FIXTURES_DIR/plan.md" "$feature_dir/plan.md"

    # Return relative path for assertions
    echo "specs/$feature_name"
}

# Create a complete mock feature (with tasks and tests)
create_complete_mock_feature() {
    local feature_name="${1:-001-test-feature}"
    local relative_dir
    relative_dir=$(create_mock_feature "$feature_name")
    local feature_dir="$TEST_DIR/$relative_dir"

    cp "$FIXTURES_DIR/tasks.md" "$feature_dir/tasks.md"
    mkdir -p "$feature_dir/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$feature_dir/tests/test-specs.md"

    echo "$relative_dir"
}

# Assert that a string contains a substring
assert_contains() {
    local haystack="$1"
    local needle="$2"

    if [[ "$haystack" != *"$needle"* ]]; then
        echo "Expected to find '$needle' in '$haystack'" >&2
        return 1
    fi
}

# Assert that a string does not contain a substring
assert_not_contains() {
    local haystack="$1"
    local needle="$2"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo "Expected NOT to find '$needle' in '$haystack'" >&2
        return 1
    fi
}

# Assert JSON field value
assert_json_field() {
    local json="$1"
    local field="$2"
    local expected="$3"

    local actual
    actual=$(echo "$json" | jq -r ".$field")

    if [[ "$actual" != "$expected" ]]; then
        echo "Expected $field to be '$expected' but got '$actual'" >&2
        return 1
    fi
}
