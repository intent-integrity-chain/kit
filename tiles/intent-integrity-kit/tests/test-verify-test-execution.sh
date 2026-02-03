#!/usr/bin/env bash
#
# Tests for verify-test-execution.sh
#
# Usage:
#   ./test-verify-test-execution.sh
#

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/../skills/iikit-core/scripts/bash/verify-test-execution.sh"

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)); }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# Create temp directory for test fixtures
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

#
# count-expected tests
#

test_count_expected_empty_file() {
    log_section "count-expected: empty file"
    ((TESTS_RUN++))

    echo "" > "$TEMP_DIR/empty-specs.md"
    local result
    result=$("$VERIFY_SCRIPT" count-expected "$TEMP_DIR/empty-specs.md")

    if [[ "$result" == "0" ]]; then
        log_pass "empty file returns 0"
    else
        log_fail "empty file should return 0, got: $result"
    fi
}

test_count_expected_no_tests() {
    log_section "count-expected: file with no test specs"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/no-tests.md" << 'EOF'
# Test Specifications

Some text without test IDs.

## Section

More text.
EOF

    local result
    result=$("$VERIFY_SCRIPT" count-expected "$TEMP_DIR/no-tests.md")

    if [[ "$result" == "0" ]]; then
        log_pass "file with no TS-XXX returns 0"
    else
        log_fail "file with no TS-XXX should return 0, got: $result"
    fi
}

test_count_expected_single_test() {
    log_section "count-expected: single test spec"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/single-test.md" << 'EOF'
# Test Specifications

### TS-001: User login

Test that users can log in.
EOF

    local result
    result=$("$VERIFY_SCRIPT" count-expected "$TEMP_DIR/single-test.md")

    if [[ "$result" == "1" ]]; then
        log_pass "single test spec returns 1"
    else
        log_fail "single test spec should return 1, got: $result"
    fi
}

test_count_expected_multiple_tests() {
    log_section "count-expected: multiple test specs"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/multi-tests.md" << 'EOF'
# Test Specifications

### TS-001: User login
Test that users can log in.

### TS-002: User logout
Test that users can log out.

### TS-003: Password reset
Test password reset flow.

### TS-004: Session timeout
Test session timeout behavior.

### TS-005: Remember me
Test remember me functionality.
EOF

    local result
    result=$("$VERIFY_SCRIPT" count-expected "$TEMP_DIR/multi-tests.md")

    if [[ "$result" == "5" ]]; then
        log_pass "5 test specs returns 5"
    else
        log_fail "5 test specs should return 5, got: $result"
    fi
}

test_count_expected_missing_file() {
    log_section "count-expected: missing file"
    ((TESTS_RUN++))

    local result
    result=$("$VERIFY_SCRIPT" count-expected "$TEMP_DIR/nonexistent.md")

    if [[ "$result" == "0" ]]; then
        log_pass "missing file returns 0"
    else
        log_fail "missing file should return 0, got: $result"
    fi
}

test_count_expected_mixed_headers() {
    log_section "count-expected: mixed header levels"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/mixed-headers.md" << 'EOF'
# Test Specifications

## TS-000: This should NOT match (h2 not h3)

### TS-001: This SHOULD match
Test content.

#### TS-002: This should NOT match (h4 not h3)

### TS-003: This SHOULD match
More test content.

###TS-004: No space - should NOT match
EOF

    local result
    result=$("$VERIFY_SCRIPT" count-expected "$TEMP_DIR/mixed-headers.md")

    if [[ "$result" == "2" ]]; then
        log_pass "only h3 TS-XXX headers counted (2)"
    else
        log_fail "should count only h3 headers, expected 2, got: $result"
    fi
}

#
# parse-output tests - Jest/Vitest
#

test_parse_jest_all_passed() {
    log_section "parse-output: Jest all passed"
    ((TESTS_RUN++))

    local output="Tests: 15 passed, 15 total"
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 15' && \
       echo "$result" | grep -q '"failed": 0' && \
       echo "$result" | grep -q '"total": 15'; then
        log_pass "Jest all passed parsed correctly"
    else
        log_fail "Jest all passed parsing failed: $result"
    fi
}

test_parse_jest_with_failures() {
    log_section "parse-output: Jest with failures"
    ((TESTS_RUN++))

    local output="Tests: 12 passed, 3 failed, 15 total"
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 12' && \
       echo "$result" | grep -q '"failed": 3' && \
       echo "$result" | grep -q '"total": 15'; then
        log_pass "Jest with failures parsed correctly"
    else
        log_fail "Jest with failures parsing failed: $result"
    fi
}

test_parse_vitest_output() {
    log_section "parse-output: Vitest output"
    ((TESTS_RUN++))

    local output="Tests: 8 passed, 2 failed"
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 8' && \
       echo "$result" | grep -q '"failed": 2' && \
       echo "$result" | grep -q '"total": 10'; then
        log_pass "Vitest output parsed correctly"
    else
        log_fail "Vitest output parsing failed: $result"
    fi
}

#
# parse-output tests - Pytest
#

test_parse_pytest_all_passed() {
    log_section "parse-output: Pytest all passed"
    ((TESTS_RUN++))

    local output="==================== 25 passed in 1.23s ===================="
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 25' && \
       echo "$result" | grep -q '"failed": 0' && \
       echo "$result" | grep -q '"total": 25'; then
        log_pass "Pytest all passed parsed correctly"
    else
        log_fail "Pytest all passed parsing failed: $result"
    fi
}

test_parse_pytest_with_failures() {
    log_section "parse-output: Pytest with failures"
    ((TESTS_RUN++))

    local output="==================== 20 passed, 5 failed in 2.45s ===================="
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 20' && \
       echo "$result" | grep -q '"failed": 5' && \
       echo "$result" | grep -q '"total": 25'; then
        log_pass "Pytest with failures parsed correctly"
    else
        log_fail "Pytest with failures parsing failed: $result"
    fi
}

#
# parse-output tests - Go test
#

test_parse_go_test_passed() {
    log_section "parse-output: Go test passed"
    ((TESTS_RUN++))

    local output="--- PASS: TestLogin (0.00s)
--- PASS: TestLogout (0.00s)
--- PASS: TestSession (0.01s)
ok      mypackage   0.123s"
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 3' && \
       echo "$result" | grep -q '"failed": 0' && \
       echo "$result" | grep -q '"total": 3'; then
        log_pass "Go test passed parsed correctly"
    else
        log_fail "Go test passed parsing failed: $result"
    fi
}

test_parse_go_test_with_failures() {
    log_section "parse-output: Go test with failures"
    ((TESTS_RUN++))

    local output="--- PASS: TestLogin (0.00s)
--- FAIL: TestLogout (0.00s)
--- PASS: TestSession (0.01s)
--- FAIL: TestTimeout (0.02s)
FAIL    mypackage   0.123s"
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 2' && \
       echo "$result" | grep -q '"failed": 2' && \
       echo "$result" | grep -q '"total": 4'; then
        log_pass "Go test with failures parsed correctly"
    else
        log_fail "Go test with failures parsing failed: $result"
    fi
}

#
# parse-output tests - Playwright
#

test_parse_playwright_passed() {
    log_section "parse-output: Playwright passed"
    ((TESTS_RUN++))

    local output="Running 10 tests using 4 workers
  10 passed (5.2s)"
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 10' && \
       echo "$result" | grep -q '"failed": 0' && \
       echo "$result" | grep -q '"total": 10'; then
        log_pass "Playwright passed parsed correctly"
    else
        log_fail "Playwright passed parsing failed: $result"
    fi
}

test_parse_playwright_with_failures() {
    log_section "parse-output: Playwright with failures"
    ((TESTS_RUN++))

    local output="Running 10 tests using 4 workers
  7 passed (5.2s)
  3 failed"
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 7' && \
       echo "$result" | grep -q '"failed": 3' && \
       echo "$result" | grep -q '"total": 10'; then
        log_pass "Playwright with failures parsed correctly"
    else
        log_fail "Playwright with failures parsing failed: $result"
    fi
}

#
# parse-output tests - Mocha
#

test_parse_mocha_passed() {
    log_section "parse-output: Mocha passed"
    ((TESTS_RUN++))

    local output="  18 passing (234ms)"
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 18' && \
       echo "$result" | grep -q '"failed": 0' && \
       echo "$result" | grep -q '"total": 18'; then
        log_pass "Mocha passed parsed correctly"
    else
        log_fail "Mocha passed parsing failed: $result"
    fi
}

test_parse_mocha_with_failures() {
    log_section "parse-output: Mocha with failures"
    ((TESTS_RUN++))

    local output="  15 passing (234ms)
  3 failing"
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 15' && \
       echo "$result" | grep -q '"failed": 3' && \
       echo "$result" | grep -q '"total": 18'; then
        log_pass "Mocha with failures parsed correctly"
    else
        log_fail "Mocha with failures parsing failed: $result"
    fi
}

#
# parse-output tests - edge cases
#

test_parse_unrecognized_output() {
    log_section "parse-output: unrecognized output"
    ((TESTS_RUN++))

    local output="Some random output that is not from a test runner"
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 0' && \
       echo "$result" | grep -q '"failed": 0' && \
       echo "$result" | grep -q '"total": 0'; then
        log_pass "unrecognized output returns zeros"
    else
        log_fail "unrecognized output should return zeros: $result"
    fi
}

test_parse_empty_output() {
    log_section "parse-output: empty output"
    ((TESTS_RUN++))

    local output=""
    local result
    result=$("$VERIFY_SCRIPT" parse-output "$output")

    if echo "$result" | grep -q '"passed": 0' && \
       echo "$result" | grep -q '"failed": 0' && \
       echo "$result" | grep -q '"total": 0'; then
        log_pass "empty output returns zeros"
    else
        log_fail "empty output should return zeros: $result"
    fi
}

#
# verify tests
#

test_verify_all_passing() {
    log_section "verify: all tests passing"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/verify-specs.md" << 'EOF'
### TS-001: Test one
### TS-002: Test two
### TS-003: Test three
EOF

    local test_output="Tests: 3 passed, 3 total"
    local result
    result=$("$VERIFY_SCRIPT" verify "$TEMP_DIR/verify-specs.md" "$test_output")

    if echo "$result" | grep -q '"status": "PASS"'; then
        log_pass "verify returns PASS when all tests pass"
    else
        log_fail "verify should return PASS: $result"
    fi
}

test_verify_tests_failing() {
    log_section "verify: some tests failing"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/verify-specs.md" << 'EOF'
### TS-001: Test one
### TS-002: Test two
### TS-003: Test three
EOF

    local test_output="Tests: 2 passed, 1 failed, 3 total"
    local result
    result=$("$VERIFY_SCRIPT" verify "$TEMP_DIR/verify-specs.md" "$test_output")

    if echo "$result" | grep -q '"status": "TESTS_FAILING"'; then
        log_pass "verify returns TESTS_FAILING when tests fail"
    else
        log_fail "verify should return TESTS_FAILING: $result"
    fi
}

test_verify_incomplete() {
    log_section "verify: incomplete test run"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/verify-specs.md" << 'EOF'
### TS-001: Test one
### TS-002: Test two
### TS-003: Test three
### TS-004: Test four
### TS-005: Test five
EOF

    local test_output="Tests: 3 passed, 3 total"
    local result
    result=$("$VERIFY_SCRIPT" verify "$TEMP_DIR/verify-specs.md" "$test_output")

    if echo "$result" | grep -q '"status": "INCOMPLETE"'; then
        log_pass "verify returns INCOMPLETE when fewer tests run than expected"
    else
        log_fail "verify should return INCOMPLETE: $result"
    fi
}

test_verify_no_tests_run() {
    log_section "verify: no tests detected"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/verify-specs.md" << 'EOF'
### TS-001: Test one
EOF

    local test_output="Build completed successfully"
    local result
    result=$("$VERIFY_SCRIPT" verify "$TEMP_DIR/verify-specs.md" "$test_output")

    if echo "$result" | grep -q '"status": "NO_TESTS_RUN"'; then
        log_pass "verify returns NO_TESTS_RUN when no tests detected"
    else
        log_fail "verify should return NO_TESTS_RUN: $result"
    fi
}

test_verify_more_tests_than_expected() {
    log_section "verify: more tests than expected (still passes)"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/verify-specs.md" << 'EOF'
### TS-001: Test one
### TS-002: Test two
EOF

    local test_output="Tests: 10 passed, 10 total"
    local result
    result=$("$VERIFY_SCRIPT" verify "$TEMP_DIR/verify-specs.md" "$test_output")

    if echo "$result" | grep -q '"status": "PASS"'; then
        log_pass "verify returns PASS when more tests run than expected"
    else
        log_fail "verify should return PASS (more is fine): $result"
    fi
}

test_verify_json_structure() {
    log_section "verify: JSON structure is valid"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/verify-specs.md" << 'EOF'
### TS-001: Test one
EOF

    local test_output="Tests: 1 passed, 1 total"
    local result
    result=$("$VERIFY_SCRIPT" verify "$TEMP_DIR/verify-specs.md" "$test_output")

    # Check all required fields exist
    if echo "$result" | grep -q '"status":' && \
       echo "$result" | grep -q '"message":' && \
       echo "$result" | grep -q '"expected":' && \
       echo "$result" | grep -q '"actual":' && \
       echo "$result" | grep -q '"total":' && \
       echo "$result" | grep -q '"passed":' && \
       echo "$result" | grep -q '"failed":'; then
        log_pass "verify returns valid JSON structure"
    else
        log_fail "verify JSON structure incomplete: $result"
    fi
}

#
# help command tests
#

test_help_command() {
    log_section "help: shows usage"
    ((TESTS_RUN++))

    local result
    result=$("$VERIFY_SCRIPT" help)

    if echo "$result" | grep -q "Test Execution Verification" && \
       echo "$result" | grep -q "count-expected" && \
       echo "$result" | grep -q "parse-output" && \
       echo "$result" | grep -q "verify"; then
        log_pass "help shows all commands"
    else
        log_fail "help output incomplete: $result"
    fi
}

test_default_shows_help() {
    log_section "default: shows help"
    ((TESTS_RUN++))

    local result
    result=$("$VERIFY_SCRIPT")

    if echo "$result" | grep -q "Test Execution Verification"; then
        log_pass "running with no args shows help"
    else
        log_fail "no args should show help: $result"
    fi
}

#
# Main
#

main() {
    echo ""
    echo "========================================"
    echo "  verify-test-execution.sh Tests"
    echo "========================================"
    echo ""

    # Check script exists
    if [[ ! -f "$VERIFY_SCRIPT" ]]; then
        echo -e "${RED}ERROR: $VERIFY_SCRIPT not found${NC}"
        exit 1
    fi

    # count-expected tests
    test_count_expected_empty_file
    test_count_expected_no_tests
    test_count_expected_single_test
    test_count_expected_multiple_tests
    test_count_expected_missing_file
    test_count_expected_mixed_headers

    # parse-output tests - Jest/Vitest
    test_parse_jest_all_passed
    test_parse_jest_with_failures
    test_parse_vitest_output

    # parse-output tests - Pytest
    test_parse_pytest_all_passed
    test_parse_pytest_with_failures

    # parse-output tests - Go test
    test_parse_go_test_passed
    test_parse_go_test_with_failures

    # parse-output tests - Playwright
    test_parse_playwright_passed
    test_parse_playwright_with_failures

    # parse-output tests - Mocha
    test_parse_mocha_passed
    test_parse_mocha_with_failures

    # parse-output tests - edge cases
    test_parse_unrecognized_output
    test_parse_empty_output

    # verify tests
    test_verify_all_passing
    test_verify_tests_failing
    test_verify_incomplete
    test_verify_no_tests_run
    test_verify_more_tests_than_expected
    test_verify_json_structure

    # help tests
    test_help_command
    test_default_shows_help

    # Summary
    log_section "Summary"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"

    [[ $TESTS_FAILED -gt 0 ]] && exit 1
    exit 0
}

main "$@"
