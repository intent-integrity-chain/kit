#!/usr/bin/env bash
# Verify that tests were actually executed and counts match expectations
# Usage: verify-test-execution.sh <test-specs-file> <test-output-file-or-string>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Count expected tests from test-specs.md
count_expected_tests() {
    local test_specs_file="$1"

    if [[ ! -f "$test_specs_file" ]]; then
        echo "0"
        return
    fi

    # Count TS-XXX patterns (test spec IDs)
    # Note: grep -c returns 0 count with exit 1 when no matches, so capture output first
    local count
    count=$(grep -cE "^###[[:space:]]+TS-[0-9]+" "$test_specs_file" 2>/dev/null) || true
    echo "${count:-0}"
}

# Parse test count from common test runner outputs
# Supports: Jest, Vitest, Pytest, Go test, Playwright, Mocha
parse_test_output() {
    local output="$1"
    local passed=0
    local failed=0
    local total=0

    # Jest/Vitest: "Tests: X passed, Y failed, Z total"
    if echo "$output" | grep -qE "Tests:.*passed"; then
        passed=$(echo "$output" | grep -oE "([0-9]+) passed" | grep -oE "[0-9]+" | tail -1) || passed=0
        failed=$(echo "$output" | grep -oE "([0-9]+) failed" | grep -oE "[0-9]+" | tail -1) || failed=0
        total=$((passed + failed))
    # Pytest: "X passed" or "X passed, Y failed"
    elif echo "$output" | grep -qE "[0-9]+ passed"; then
        passed=$(echo "$output" | grep -oE "([0-9]+) passed" | grep -oE "[0-9]+" | tail -1) || passed=0
        failed=$(echo "$output" | grep -oE "([0-9]+) failed" | grep -oE "[0-9]+" | tail -1) || failed=0
        total=$((passed + failed))
    # Go test: "ok" or "FAIL" with test counts, or "--- PASS:" counts
    # Note: Use -- to prevent "--- PASS:" from being interpreted as options
    elif echo "$output" | grep -qE -- "(^ok[[:space:]]|^FAIL[[:space:]]|--- PASS:|--- FAIL:)"; then
        passed=$(echo "$output" | grep -cE -- "--- PASS:" 2>/dev/null) || true
        failed=$(echo "$output" | grep -cE -- "--- FAIL:" 2>/dev/null) || true
        passed=${passed:-0}
        failed=${failed:-0}
        total=$((passed + failed))
    # Playwright: "X passed" or "X failed"
    elif echo "$output" | grep -qE "[0-9]+ (passed|failed)"; then
        passed=$(echo "$output" | grep -oE "([0-9]+) passed" | grep -oE "[0-9]+" | tail -1) || passed=0
        failed=$(echo "$output" | grep -oE "([0-9]+) failed" | grep -oE "[0-9]+" | tail -1) || failed=0
        total=$((passed + failed))
    # Mocha: "X passing" "Y failing"
    elif echo "$output" | grep -qE "[0-9]+ passing"; then
        passed=$(echo "$output" | grep -oE "([0-9]+) passing" | grep -oE "[0-9]+" | tail -1) || passed=0
        failed=$(echo "$output" | grep -oE "([0-9]+) failing" | grep -oE "[0-9]+" | tail -1) || failed=0
        total=$((passed + failed))
    fi

    echo "{\"passed\": $passed, \"failed\": $failed, \"total\": $total}"
}

# Verify test execution against expectations
verify_execution() {
    local test_specs_file="$1"
    local test_output="$2"

    local expected
    expected=$(count_expected_tests "$test_specs_file")

    local results
    results=$(parse_test_output "$test_output")

    local actual_total
    actual_total=$(echo "$results" | grep -oE '"total": [0-9]+' | grep -oE '[0-9]+')

    local passed
    passed=$(echo "$results" | grep -oE '"passed": [0-9]+' | grep -oE '[0-9]+')

    local failed
    failed=$(echo "$results" | grep -oE '"failed": [0-9]+' | grep -oE '[0-9]+')

    # Determine status
    local status="UNKNOWN"
    local message=""

    if [[ "$actual_total" -eq 0 ]]; then
        status="NO_TESTS_RUN"
        message="Could not detect any test execution in output"
    elif [[ "$failed" -gt 0 ]]; then
        status="TESTS_FAILING"
        message="$failed tests failing - fix code before proceeding"
    elif [[ "$expected" -gt 0 ]] && [[ "$actual_total" -lt "$expected" ]]; then
        status="INCOMPLETE"
        message="Only $actual_total tests run, expected $expected from test-specs.md"
    elif [[ "$passed" -gt 0 ]] && [[ "$failed" -eq 0 ]]; then
        status="PASS"
        message="All $passed tests passing"
    fi

    cat <<EOF
{
    "status": "$status",
    "message": "$message",
    "expected": $expected,
    "actual": {
        "total": $actual_total,
        "passed": $passed,
        "failed": $failed
    }
}
EOF
}

# Main
case "${1:-help}" in
    count-expected)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 count-expected <test-specs-file>"
            exit 1
        fi
        count_expected_tests "$2"
        ;;
    parse-output)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 parse-output <test-output-string>"
            exit 1
        fi
        parse_test_output "$2"
        ;;
    verify)
        if [[ $# -lt 3 ]]; then
            echo "Usage: $0 verify <test-specs-file> <test-output-string>"
            exit 1
        fi
        verify_execution "$2" "$3"
        ;;
    help|*)
        echo "Test Execution Verification"
        echo ""
        echo "Commands:"
        echo "  count-expected <test-specs-file>     Count TS-XXX entries in test specs"
        echo "  parse-output <output-string>         Parse test runner output for counts"
        echo "  verify <specs-file> <output>         Compare expected vs actual"
        echo ""
        echo "Supported test runners: Jest, Vitest, Pytest, Go test, Playwright, Mocha"
        ;;
esac
