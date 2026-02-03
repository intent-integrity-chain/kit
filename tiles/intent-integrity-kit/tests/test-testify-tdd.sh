#!/usr/bin/env bash
#
# Tests for testify-tdd.sh assertion integrity functions
#
# Usage:
#   ./test-testify-tdd.sh
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
TESTIFY_SCRIPT="$SCRIPT_DIR/../skills/iikit-core/scripts/bash/testify-tdd.sh"

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)); }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# Create temp directory for test fixtures
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# =============================================================================
# extract-assertions tests
# =============================================================================

test_extract_assertions_empty_file() {
    log_section "extract-assertions: empty file"
    ((TESTS_RUN++))

    echo "" > "$TEMP_DIR/empty.md"
    local result
    result=$("$TESTIFY_SCRIPT" extract-assertions "$TEMP_DIR/empty.md")

    if [[ -z "$result" ]]; then
        log_pass "empty file returns empty string"
    else
        log_fail "empty file should return empty, got: $result"
    fi
}

test_extract_assertions_no_assertions() {
    log_section "extract-assertions: file with no assertions"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/no-assertions.md" << 'EOF'
# Test Specifications

Some regular text without any Given/When/Then.

## Section

More text.
EOF

    local result
    result=$("$TESTIFY_SCRIPT" extract-assertions "$TEMP_DIR/no-assertions.md")

    if [[ -z "$result" ]]; then
        log_pass "file without assertions returns empty"
    else
        log_fail "file without assertions should return empty, got: $result"
    fi
}

test_extract_assertions_with_assertions() {
    log_section "extract-assertions: file with assertions"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/with-assertions.md" << 'EOF'
# Test Specifications

### TS-001: User Login

**Given**: User is on login page
**When**: User enters valid credentials
**Then**: User is redirected to dashboard

### TS-002: Invalid Login

**Given**: User is on login page
**When**: User enters invalid credentials
**Then**: Error message is displayed
EOF

    local result
    result=$("$TESTIFY_SCRIPT" extract-assertions "$TEMP_DIR/with-assertions.md")
    local line_count
    line_count=$(echo "$result" | wc -l | tr -d ' ')

    if [[ "$line_count" -eq 6 ]]; then
        log_pass "extracted 6 assertion lines"
    else
        log_fail "should extract 6 assertion lines, got $line_count"
    fi
}

test_extract_assertions_sorted() {
    log_section "extract-assertions: output is sorted"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/unsorted.md" << 'EOF'
**When**: Action B
**Given**: State A
**Then**: Result C
EOF

    local result
    result=$("$TESTIFY_SCRIPT" extract-assertions "$TEMP_DIR/unsorted.md")
    local first_line
    first_line=$(echo "$result" | head -1)

    # After LC_ALL=C sort, **Given should come before **Then and **When
    if [[ "$first_line" == *"Given"* ]]; then
        log_pass "assertions are sorted (Given before When/Then)"
    else
        log_fail "assertions should be sorted, first line: $first_line"
    fi
}

test_extract_assertions_missing_file() {
    log_section "extract-assertions: missing file"
    ((TESTS_RUN++))

    local result
    result=$("$TESTIFY_SCRIPT" extract-assertions "$TEMP_DIR/nonexistent.md")

    if [[ -z "$result" ]]; then
        log_pass "missing file returns empty"
    else
        log_fail "missing file should return empty, got: $result"
    fi
}

# =============================================================================
# compute-hash tests
# =============================================================================

test_compute_hash_no_assertions() {
    log_section "compute-hash: no assertions"
    ((TESTS_RUN++))

    echo "No assertions here" > "$TEMP_DIR/no-assertions.md"
    local result
    result=$("$TESTIFY_SCRIPT" compute-hash "$TEMP_DIR/no-assertions.md")

    if [[ "$result" == "NO_ASSERTIONS" ]]; then
        log_pass "no assertions returns NO_ASSERTIONS"
    else
        log_fail "no assertions should return NO_ASSERTIONS, got: $result"
    fi
}

test_compute_hash_deterministic() {
    log_section "compute-hash: deterministic"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: User is logged in
**When**: User clicks logout
**Then**: User is logged out
EOF

    local hash1 hash2
    hash1=$("$TESTIFY_SCRIPT" compute-hash "$TEMP_DIR/test-specs.md")
    hash2=$("$TESTIFY_SCRIPT" compute-hash "$TEMP_DIR/test-specs.md")

    if [[ "$hash1" == "$hash2" ]]; then
        log_pass "hash is deterministic"
    else
        log_fail "hash should be deterministic: $hash1 vs $hash2"
    fi
}

test_compute_hash_changes_on_modification() {
    log_section "compute-hash: changes when assertions modified"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: User is logged in
**When**: User clicks logout
**Then**: User is logged out
EOF

    local hash1
    hash1=$("$TESTIFY_SCRIPT" compute-hash "$TEMP_DIR/test-specs.md")

    # Modify an assertion
    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: User is logged in
**When**: User clicks logout
**Then**: User sees goodbye message
EOF

    local hash2
    hash2=$("$TESTIFY_SCRIPT" compute-hash "$TEMP_DIR/test-specs.md")

    if [[ "$hash1" != "$hash2" ]]; then
        log_pass "hash changes when assertions modified"
    else
        log_fail "hash should change when assertions modified"
    fi
}

test_compute_hash_format() {
    log_section "compute-hash: valid SHA256 format"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: User is logged in
**When**: User clicks logout
**Then**: User is logged out
EOF

    local hash
    hash=$("$TESTIFY_SCRIPT" compute-hash "$TEMP_DIR/test-specs.md")

    # SHA256 is 64 hex characters
    if [[ "$hash" =~ ^[a-f0-9]{64}$ ]]; then
        log_pass "hash is valid SHA256 format (64 hex chars)"
    else
        log_fail "hash should be 64 hex chars, got: $hash"
    fi
}

# =============================================================================
# store-hash / verify-hash tests
# =============================================================================

test_store_hash_creates_context() {
    log_section "store-hash: creates context file"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: User is logged in
**Then**: User sees dashboard
EOF

    rm -f "$TEMP_DIR/context.json"
    "$TESTIFY_SCRIPT" store-hash "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" > /dev/null

    if [[ -f "$TEMP_DIR/context.json" ]]; then
        log_pass "context file created"
    else
        log_fail "context file should be created"
    fi
}

test_store_hash_valid_json() {
    log_section "store-hash: creates valid JSON"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: User is logged in
**Then**: User sees dashboard
EOF

    "$TESTIFY_SCRIPT" store-hash "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" > /dev/null

    if jq empty "$TEMP_DIR/context.json" 2>/dev/null; then
        log_pass "context file is valid JSON"
    else
        log_fail "context file should be valid JSON"
    fi
}

test_store_hash_has_testify_section() {
    log_section "store-hash: has testify section"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: Test
**Then**: Result
EOF

    "$TESTIFY_SCRIPT" store-hash "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" > /dev/null

    local has_section
    has_section=$(jq 'has("testify")' "$TEMP_DIR/context.json")

    if [[ "$has_section" == "true" ]]; then
        log_pass "context has testify section"
    else
        log_fail "context should have testify section"
    fi
}

test_verify_hash_valid() {
    log_section "verify-hash: returns valid when unchanged"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: Test state
**When**: Test action
**Then**: Test result
EOF

    "$TESTIFY_SCRIPT" store-hash "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" > /dev/null
    local result
    result=$("$TESTIFY_SCRIPT" verify-hash "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json")

    if [[ "$result" == "valid" ]]; then
        log_pass "unchanged file returns valid"
    else
        log_fail "unchanged file should return valid, got: $result"
    fi
}

test_verify_hash_invalid() {
    log_section "verify-hash: returns invalid when modified"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: Original state
**Then**: Original result
EOF

    "$TESTIFY_SCRIPT" store-hash "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" > /dev/null

    # Modify the file
    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: Modified state
**Then**: Modified result
EOF

    local result
    result=$("$TESTIFY_SCRIPT" verify-hash "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json")

    if [[ "$result" == "invalid" ]]; then
        log_pass "modified file returns invalid"
    else
        log_fail "modified file should return invalid, got: $result"
    fi
}

test_verify_hash_missing_context() {
    log_section "verify-hash: returns missing when no context"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: Test
**Then**: Result
EOF

    rm -f "$TEMP_DIR/context.json"
    local result
    result=$("$TESTIFY_SCRIPT" verify-hash "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json")

    if [[ "$result" == "missing" ]]; then
        log_pass "missing context returns missing"
    else
        log_fail "missing context should return missing, got: $result"
    fi
}

test_verify_hash_missing_testify_section() {
    log_section "verify-hash: returns missing when no testify section"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: Test
**Then**: Result
EOF

    echo '{"other": "data"}' > "$TEMP_DIR/context.json"
    local result
    result=$("$TESTIFY_SCRIPT" verify-hash "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json")

    if [[ "$result" == "missing" ]]; then
        log_pass "missing testify section returns missing"
    else
        log_fail "missing testify section should return missing, got: $result"
    fi
}

# =============================================================================
# TDD assessment tests
# =============================================================================

test_assess_tdd_mandatory() {
    log_section "assess-tdd: detects mandatory TDD"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/constitution.md" << 'EOF'
# Project Constitution

## Testing Principles

All code MUST use TDD methodology.
EOF

    local result
    result=$("$TESTIFY_SCRIPT" assess-tdd "$TEMP_DIR/constitution.md")
    local determination
    determination=$(echo "$result" | jq -r '.determination')

    if [[ "$determination" == "mandatory" ]]; then
        log_pass "MUST TDD returns mandatory"
    else
        log_fail "MUST TDD should return mandatory, got: $determination"
    fi
}

test_assess_tdd_optional() {
    log_section "assess-tdd: detects optional (no TDD mention)"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/constitution.md" << 'EOF'
# Project Constitution

## Principles

Write clean code.
EOF

    local result
    result=$("$TESTIFY_SCRIPT" assess-tdd "$TEMP_DIR/constitution.md")
    local determination
    determination=$(echo "$result" | jq -r '.determination')

    if [[ "$determination" == "optional" ]]; then
        log_pass "no TDD mention returns optional"
    else
        log_fail "no TDD mention should return optional, got: $determination"
    fi
}

test_assess_tdd_test_first() {
    log_section "assess-tdd: detects test-first requirement"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/constitution.md" << 'EOF'
# Constitution

MUST write tests before implementation (test-first).
EOF

    local result
    result=$("$TESTIFY_SCRIPT" assess-tdd "$TEMP_DIR/constitution.md")
    local determination
    determination=$(echo "$result" | jq -r '.determination')

    if [[ "$determination" == "mandatory" ]]; then
        log_pass "test-first MUST returns mandatory"
    else
        log_fail "test-first MUST should return mandatory, got: $determination"
    fi
}

test_get_tdd_determination() {
    log_section "get-tdd-determination: returns just determination"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/constitution.md" << 'EOF'
# Constitution

TDD MUST be used for all features.
EOF

    local result
    result=$("$TESTIFY_SCRIPT" get-tdd-determination "$TEMP_DIR/constitution.md")

    if [[ "$result" == "mandatory" ]]; then
        log_pass "get-tdd-determination returns just the value"
    else
        log_fail "get-tdd-determination should return 'mandatory', got: $result"
    fi
}

# =============================================================================
# comprehensive-check tests
# =============================================================================

test_comprehensive_check_pass() {
    log_section "comprehensive-check: PASS when valid"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: User logged in
**Then**: Dashboard visible
EOF

    cat > "$TEMP_DIR/constitution.md" << 'EOF'
# Constitution
Write good code.
EOF

    # Store hash first
    "$TESTIFY_SCRIPT" store-hash "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" > /dev/null

    local result
    result=$("$TESTIFY_SCRIPT" comprehensive-check "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" "$TEMP_DIR/constitution.md")
    local status
    status=$(echo "$result" | jq -r '.overall_status')

    if [[ "$status" == "PASS" ]]; then
        log_pass "valid hash returns PASS"
    else
        log_fail "valid hash should return PASS, got: $status"
    fi
}

test_comprehensive_check_blocked_invalid() {
    log_section "comprehensive-check: BLOCKED when hash invalid"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: Original
**Then**: Result
EOF

    cat > "$TEMP_DIR/constitution.md" << 'EOF'
# Constitution
EOF

    # Store hash
    "$TESTIFY_SCRIPT" store-hash "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" > /dev/null

    # Modify assertions
    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: Modified
**Then**: Different
EOF

    local result
    result=$("$TESTIFY_SCRIPT" comprehensive-check "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" "$TEMP_DIR/constitution.md")
    local status
    status=$(echo "$result" | jq -r '.overall_status')

    if [[ "$status" == "BLOCKED" ]]; then
        log_pass "invalid hash returns BLOCKED"
    else
        log_fail "invalid hash should return BLOCKED, got: $status"
    fi
}

test_comprehensive_check_blocked_mandatory_missing() {
    log_section "comprehensive-check: BLOCKED when TDD mandatory and hash missing"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: Test
**Then**: Result
EOF

    cat > "$TEMP_DIR/constitution.md" << 'EOF'
# Constitution
TDD MUST be used.
EOF

    # Don't store hash - context is empty
    echo '{}' > "$TEMP_DIR/context.json"

    local result
    result=$("$TESTIFY_SCRIPT" comprehensive-check "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" "$TEMP_DIR/constitution.md")
    local status
    status=$(echo "$result" | jq -r '.overall_status')

    if [[ "$status" == "BLOCKED" ]]; then
        log_pass "mandatory TDD with missing hash returns BLOCKED"
    else
        log_fail "mandatory TDD with missing hash should return BLOCKED, got: $status"
    fi
}

test_comprehensive_check_warn_optional_missing() {
    log_section "comprehensive-check: WARN when TDD optional and hash missing"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: Test
**Then**: Result
EOF

    cat > "$TEMP_DIR/constitution.md" << 'EOF'
# Constitution
Write good code.
EOF

    # Don't store hash
    echo '{}' > "$TEMP_DIR/context.json"

    local result
    result=$("$TESTIFY_SCRIPT" comprehensive-check "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" "$TEMP_DIR/constitution.md")
    local status
    status=$(echo "$result" | jq -r '.overall_status')

    if [[ "$status" == "WARN" ]]; then
        log_pass "optional TDD with missing hash returns WARN"
    else
        log_fail "optional TDD with missing hash should return WARN, got: $status"
    fi
}

test_comprehensive_check_json_structure() {
    log_section "comprehensive-check: valid JSON structure"
    ((TESTS_RUN++))

    cat > "$TEMP_DIR/test-specs.md" << 'EOF'
**Given**: Test
**Then**: Result
EOF

    cat > "$TEMP_DIR/constitution.md" << 'EOF'
# Constitution
EOF

    "$TESTIFY_SCRIPT" store-hash "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" > /dev/null

    local result
    result=$("$TESTIFY_SCRIPT" comprehensive-check "$TEMP_DIR/test-specs.md" "$TEMP_DIR/context.json" "$TEMP_DIR/constitution.md")

    # Check all expected fields
    if echo "$result" | jq -e '.overall_status' > /dev/null && \
       echo "$result" | jq -e '.block_reason' > /dev/null && \
       echo "$result" | jq -e '.tdd_determination' > /dev/null && \
       echo "$result" | jq -e '.checks.context_hash' > /dev/null && \
       echo "$result" | jq -e '.checks.git_note' > /dev/null && \
       echo "$result" | jq -e '.checks.git_diff' > /dev/null; then
        log_pass "comprehensive-check returns valid JSON with all fields"
    else
        log_fail "comprehensive-check JSON missing fields: $result"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "========================================"
    echo "  testify-tdd.sh Tests"
    echo "========================================"
    echo ""

    # Check script exists
    if [[ ! -f "$TESTIFY_SCRIPT" ]]; then
        echo -e "${RED}ERROR: $TESTIFY_SCRIPT not found${NC}"
        exit 1
    fi

    # Check jq is available
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}ERROR: jq is required but not installed${NC}"
        exit 1
    fi

    # extract-assertions tests
    test_extract_assertions_empty_file
    test_extract_assertions_no_assertions
    test_extract_assertions_with_assertions
    test_extract_assertions_sorted
    test_extract_assertions_missing_file

    # compute-hash tests
    test_compute_hash_no_assertions
    test_compute_hash_deterministic
    test_compute_hash_changes_on_modification
    test_compute_hash_format

    # store-hash / verify-hash tests
    test_store_hash_creates_context
    test_store_hash_valid_json
    test_store_hash_has_testify_section
    test_verify_hash_valid
    test_verify_hash_invalid
    test_verify_hash_missing_context
    test_verify_hash_missing_testify_section

    # TDD assessment tests
    test_assess_tdd_mandatory
    test_assess_tdd_optional
    test_assess_tdd_test_first
    test_get_tdd_determination

    # comprehensive-check tests
    test_comprehensive_check_pass
    test_comprehensive_check_blocked_invalid
    test_comprehensive_check_blocked_mandatory_missing
    test_comprehensive_check_warn_optional_missing
    test_comprehensive_check_json_structure

    # Summary
    log_section "Summary"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"

    [[ $TESTS_FAILED -gt 0 ]] && exit 1
    exit 0
}

main "$@"
