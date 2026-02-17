#!/usr/bin/env bats
# Tests for testify-tdd.sh functions

load 'test_helper'

TESTIFY_SCRIPT="$SCRIPTS_DIR/testify-tdd.sh"

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# TDD Assessment tests
# =============================================================================

@test "assess-tdd: returns mandatory for MUST TDD" {
    result=$("$TESTIFY_SCRIPT" assess-tdd "$FIXTURES_DIR/constitution.md")
    assert_contains "$result" '"determination": "mandatory"'
    assert_contains "$result" '"confidence": "high"'
}

@test "assess-tdd: returns optional for no TDD indicators" {
    result=$("$TESTIFY_SCRIPT" assess-tdd "$FIXTURES_DIR/constitution-no-tdd.md")
    assert_contains "$result" '"determination": "optional"'
}

@test "assess-tdd: returns forbidden for TDD prohibition" {
    result=$("$TESTIFY_SCRIPT" assess-tdd "$FIXTURES_DIR/constitution-forbidden-tdd.md")
    assert_contains "$result" '"determination": "forbidden"'
}

@test "assess-tdd: returns error for missing file" {
    # Script returns non-zero exit and JSON with error
    run "$TESTIFY_SCRIPT" assess-tdd "/nonexistent/constitution.md"
    assert_contains "$output" '"error"'
}

@test "get-tdd-determination: returns just the determination" {
    result=$("$TESTIFY_SCRIPT" get-tdd-determination "$FIXTURES_DIR/constitution.md")
    [[ "$result" == "mandatory" ]]
}

@test "get-tdd-determination: returns unknown for missing file" {
    result=$("$TESTIFY_SCRIPT" get-tdd-determination "/nonexistent/constitution.md")
    [[ "$result" == "unknown" ]]
}

# =============================================================================
# Scenario counting tests
# =============================================================================

@test "count-scenarios: counts Given/When patterns" {
    result=$("$TESTIFY_SCRIPT" count-scenarios "$FIXTURES_DIR/spec.md")
    # The fixture has 3 acceptance scenarios
    [[ "$result" -ge 3 ]]
}

@test "count-scenarios: returns 0 for missing file" {
    result=$("$TESTIFY_SCRIPT" count-scenarios "/nonexistent/spec.md")
    [[ "$result" -eq 0 ]]
}

@test "has-scenarios: returns true for spec with scenarios" {
    result=$("$TESTIFY_SCRIPT" has-scenarios "$FIXTURES_DIR/spec.md")
    [[ "$result" == "true" ]]
}

@test "has-scenarios: returns false for spec without scenarios" {
    result=$("$TESTIFY_SCRIPT" has-scenarios "$FIXTURES_DIR/spec-incomplete.md")
    [[ "$result" == "false" ]]
}

# =============================================================================
# Assertion extraction tests
# =============================================================================

@test "extract-assertions: extracts Given/When/Then lines" {
    result=$("$TESTIFY_SCRIPT" extract-assertions "$FIXTURES_DIR/test-specs.md")
    assert_contains "$result" "**Given**:"
    assert_contains "$result" "**When**:"
    assert_contains "$result" "**Then**:"
}

@test "extract-assertions: returns empty for missing file" {
    result=$("$TESTIFY_SCRIPT" extract-assertions "/nonexistent/test-specs.md")
    [[ -z "$result" ]]
}

# =============================================================================
# Hash computation tests
# =============================================================================

@test "compute-hash: returns consistent hash" {
    hash1=$("$TESTIFY_SCRIPT" compute-hash "$FIXTURES_DIR/test-specs.md")
    hash2=$("$TESTIFY_SCRIPT" compute-hash "$FIXTURES_DIR/test-specs.md")
    [[ "$hash1" == "$hash2" ]]
}

@test "compute-hash: returns NO_ASSERTIONS for file without assertions" {
    echo "# Empty test specs" > "$TEST_DIR/empty-test-specs.md"
    result=$("$TESTIFY_SCRIPT" compute-hash "$TEST_DIR/empty-test-specs.md")
    [[ "$result" == "NO_ASSERTIONS" ]]
}

@test "compute-hash: returns 64-char hex string" {
    result=$("$TESTIFY_SCRIPT" compute-hash "$FIXTURES_DIR/test-specs.md")
    # SHA256 produces 64 hex characters
    [[ ${#result} -eq 64 ]]
}

# =============================================================================
# Hash storage and verification tests
# =============================================================================

@test "store-hash: creates context file and stores hash" {
    # Place test-specs.md in proper structure so derive_context_path resolves inside TEST_DIR
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    result=$("$TESTIFY_SCRIPT" store-hash "$test_specs")

    local context_file="$TEST_DIR/specs/001-test-feature/context.json"
    [[ -f "$context_file" ]]
    assert_contains "$(cat "$context_file")" '"assertion_hash"'
    assert_contains "$(cat "$context_file")" '"generated_at"'
}

@test "verify-hash: returns valid for matching hash" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    # Store hash first
    "$TESTIFY_SCRIPT" store-hash "$test_specs"

    # Verify it
    result=$("$TESTIFY_SCRIPT" verify-hash "$test_specs")
    [[ "$result" == "valid" ]]
}

@test "verify-hash: returns missing for no context file" {
    # Use a path where no context.json will exist
    mkdir -p "$TEST_DIR/specs/999-no-context/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/999-no-context/tests/test-specs.md"
    result=$("$TESTIFY_SCRIPT" verify-hash "$TEST_DIR/specs/999-no-context/tests/test-specs.md")
    [[ "$result" == "missing" ]]
}

@test "verify-hash: returns invalid for modified assertions" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    # Store hash
    "$TESTIFY_SCRIPT" store-hash "$test_specs"

    # Modify an assertion
    echo "**Given**: modified assertion" >> "$test_specs"

    # Verify should return invalid
    result=$("$TESTIFY_SCRIPT" verify-hash "$test_specs")
    [[ "$result" == "invalid" ]]
}

# =============================================================================
# Comprehensive check tests
# =============================================================================

@test "comprehensive-check: returns PASS for valid setup" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    "$TESTIFY_SCRIPT" store-hash "$test_specs"

    result=$("$TESTIFY_SCRIPT" comprehensive-check "$test_specs" "$FIXTURES_DIR/constitution.md")
    assert_contains "$result" '"overall_status": "PASS"'
}

@test "comprehensive-check: returns BLOCKED for tampered assertions" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    "$TESTIFY_SCRIPT" store-hash "$test_specs"

    # Tamper with assertions
    echo "**Then**: tampered assertion" >> "$test_specs"

    result=$("$TESTIFY_SCRIPT" comprehensive-check "$test_specs" "$FIXTURES_DIR/constitution.md")
    assert_contains "$result" '"overall_status": "BLOCKED"'
}

@test "comprehensive-check: includes TDD determination" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    "$TESTIFY_SCRIPT" store-hash "$test_specs"

    result=$("$TESTIFY_SCRIPT" comprehensive-check "$test_specs" "$FIXTURES_DIR/constitution.md")
    assert_contains "$result" '"tdd_determination": "mandatory"'
}
