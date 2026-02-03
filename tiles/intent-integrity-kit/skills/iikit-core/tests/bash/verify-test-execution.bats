#!/usr/bin/env bats
# Tests for verify-test-execution.sh

load 'test_helper'

VERIFY_SCRIPT="$SCRIPTS_DIR/verify-test-execution.sh"

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# count-expected tests
# =============================================================================

@test "count-expected: counts TS-XXX patterns" {
    result=$("$VERIFY_SCRIPT" count-expected "$FIXTURES_DIR/test-specs.md")
    # Fixture has 3 test specs (TS-001, TS-002, TS-003)
    [[ "$result" -eq 3 ]]
}

@test "count-expected: returns 0 for missing file" {
    result=$("$VERIFY_SCRIPT" count-expected "/nonexistent/test-specs.md")
    [[ "$result" -eq 0 ]]
}

@test "count-expected: returns 0 for file without test specs" {
    echo "# No test specs here" > "$TEST_DIR/empty.md"
    result=$("$VERIFY_SCRIPT" count-expected "$TEST_DIR/empty.md")
    [[ "$result" -eq 0 ]]
}

# =============================================================================
# parse-output tests - Jest/Vitest
# =============================================================================

@test "parse-output: parses Jest output" {
    output="Tests: 5 passed, 2 failed, 7 total"
    result=$("$VERIFY_SCRIPT" parse-output "$output")
    assert_contains "$result" '"passed": 5'
    assert_contains "$result" '"failed": 2'
    assert_contains "$result" '"total": 7'
}

@test "parse-output: parses Vitest output" {
    output="Tests: 10 passed, 0 failed, 10 total"
    result=$("$VERIFY_SCRIPT" parse-output "$output")
    assert_contains "$result" '"passed": 10'
    assert_contains "$result" '"failed": 0'
    assert_contains "$result" '"total": 10'
}

# =============================================================================
# parse-output tests - Pytest
# =============================================================================

@test "parse-output: parses Pytest output" {
    output="====== 8 passed in 1.23s ======"
    result=$("$VERIFY_SCRIPT" parse-output "$output")
    assert_contains "$result" '"passed": 8'
    assert_contains "$result" '"failed": 0'
}

@test "parse-output: parses Pytest output with failures" {
    output="====== 5 passed, 3 failed in 2.45s ======"
    result=$("$VERIFY_SCRIPT" parse-output "$output")
    assert_contains "$result" '"passed": 5'
    assert_contains "$result" '"failed": 3'
}

# =============================================================================
# parse-output tests - Go test
# =============================================================================

@test "parse-output: parses Go test output" {
    output="--- PASS: TestOne (0.00s)
--- PASS: TestTwo (0.01s)
--- FAIL: TestThree (0.00s)
ok      example.com/pkg     0.123s"
    result=$("$VERIFY_SCRIPT" parse-output "$output")
    assert_contains "$result" '"passed": 2'
    assert_contains "$result" '"failed": 1'
}

# =============================================================================
# parse-output tests - Mocha
# =============================================================================

@test "parse-output: parses Mocha output" {
    output="  12 passing (3s)
  2 failing"
    result=$("$VERIFY_SCRIPT" parse-output "$output")
    assert_contains "$result" '"passed": 12'
    assert_contains "$result" '"failed": 2'
}

# =============================================================================
# parse-output tests - Playwright
# =============================================================================

@test "parse-output: parses Playwright output" {
    output="  6 passed (5.2s)"
    result=$("$VERIFY_SCRIPT" parse-output "$output")
    assert_contains "$result" '"passed": 6'
}

# =============================================================================
# verify tests
# =============================================================================

@test "verify: returns PASS when all tests pass" {
    output="Tests: 3 passed, 0 failed, 3 total"
    result=$("$VERIFY_SCRIPT" verify "$FIXTURES_DIR/test-specs.md" "$output")
    assert_contains "$result" '"status": "PASS"'
}

@test "verify: returns TESTS_FAILING when tests fail" {
    output="Tests: 2 passed, 1 failed, 3 total"
    result=$("$VERIFY_SCRIPT" verify "$FIXTURES_DIR/test-specs.md" "$output")
    assert_contains "$result" '"status": "TESTS_FAILING"'
}

@test "verify: returns INCOMPLETE when fewer tests run" {
    output="Tests: 1 passed, 0 failed, 1 total"
    result=$("$VERIFY_SCRIPT" verify "$FIXTURES_DIR/test-specs.md" "$output")
    assert_contains "$result" '"status": "INCOMPLETE"'
}

@test "verify: returns NO_TESTS_RUN for unrecognized output" {
    output="Some random output that doesn't look like test results"
    result=$("$VERIFY_SCRIPT" verify "$FIXTURES_DIR/test-specs.md" "$output")
    assert_contains "$result" '"status": "NO_TESTS_RUN"'
}

@test "verify: includes expected count in output" {
    output="Tests: 3 passed, 0 failed, 3 total"
    result=$("$VERIFY_SCRIPT" verify "$FIXTURES_DIR/test-specs.md" "$output")
    assert_contains "$result" '"expected": 3'
}
