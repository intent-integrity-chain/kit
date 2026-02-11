#!/usr/bin/env bash
#
# Integration tests for implement skill's hash verification enforcement
#
# These tests verify that the implement workflow correctly:
# 1. Calls comprehensive-check before implementation
# 2. Blocks on tampered assertions
# 3. Blocks when TDD mandatory but hash missing
# 4. Proceeds when hash is valid
#
# Usage:
#   ./test-implement-verification.sh
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
TESTIFY_SCRIPT="$SCRIPT_DIR/../scripts/bash/testify-tdd.sh"

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)); }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# Create temp directory simulating a feature directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# =============================================================================
# Setup helpers - simulate intent-integrity-kit project structure
# =============================================================================

setup_feature_dir() {
    local feature_dir="$TEMP_DIR/specs/001-test-feature"
    mkdir -p "$feature_dir/tests"
    mkdir -p "$TEMP_DIR/.specify"
    echo "$feature_dir"
}

create_test_specs() {
    local feature_dir="$1"
    cat > "$feature_dir/tests/test-specs.md" << 'EOF'
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
}

create_constitution() {
    local tdd_requirement="$1"  # "mandatory" or "optional"

    if [[ "$tdd_requirement" == "mandatory" ]]; then
        cat > "$TEMP_DIR/CONSTITUTION.md" << 'EOF'
# Project Constitution

## Testing Requirements

All features MUST use TDD methodology.
Tests MUST be written before implementation.
EOF
    else
        cat > "$TEMP_DIR/CONSTITUTION.md" << 'EOF'
# Project Constitution

## Code Quality

Write clean, maintainable code.
EOF
    fi
}

# =============================================================================
# Simulate implement skill's verification workflow
# This is what implement SKILL.md instructs the agent to do
# =============================================================================

run_implement_verification() {
    local feature_dir="$1"
    local test_specs="$feature_dir/tests/test-specs.md"
    local context_file="$TEMP_DIR/.specify/context.json"
    local constitution_file="$TEMP_DIR/CONSTITUTION.md"

    # Step 1: Check if test-specs.md exists (implement does this)
    if [[ ! -f "$test_specs" ]]; then
        echo "NO_TEST_SPECS"
        return
    fi

    # Step 2: Run comprehensive-check (implement MUST do this)
    local result
    result=$("$TESTIFY_SCRIPT" comprehensive-check "$test_specs" "$context_file" "$constitution_file" 2>/dev/null)

    # Step 3: Parse and return overall_status
    echo "$result" | jq -r '.overall_status'
}

# =============================================================================
# Tests - Implement verification enforcement
# =============================================================================

test_implement_blocks_on_tampered_assertions() {
    log_section "implement: BLOCKS when assertions tampered"
    ((TESTS_RUN++))

    local feature_dir
    feature_dir=$(setup_feature_dir)
    create_test_specs "$feature_dir"
    create_constitution "optional"

    # Simulate testify: store hash after generating test-specs
    "$TESTIFY_SCRIPT" store-hash "$feature_dir/tests/test-specs.md" "$TEMP_DIR/.specify/context.json" > /dev/null

    # Simulate tampering: modify an assertion
    sed -i.bak 's/User is redirected to dashboard/User sees welcome message/' "$feature_dir/tests/test-specs.md"

    # Run implement verification
    local status
    status=$(run_implement_verification "$feature_dir")

    if [[ "$status" == "BLOCKED" ]]; then
        log_pass "implement blocks on tampered assertions"
    else
        log_fail "implement should BLOCK on tampered assertions, got: $status"
    fi
}

test_implement_blocks_when_tdd_mandatory_no_hash() {
    log_section "implement: BLOCKS when TDD mandatory and no hash"
    ((TESTS_RUN++))

    local feature_dir
    feature_dir=$(setup_feature_dir)
    create_test_specs "$feature_dir"
    create_constitution "mandatory"

    # Don't store hash - simulate testify was never run
    echo '{}' > "$TEMP_DIR/.specify/context.json"

    # Run implement verification
    local status
    status=$(run_implement_verification "$feature_dir")

    if [[ "$status" == "BLOCKED" ]]; then
        log_pass "implement blocks when TDD mandatory but no hash"
    else
        log_fail "implement should BLOCK when TDD mandatory and no hash, got: $status"
    fi
}

test_implement_warns_when_tdd_optional_no_hash() {
    log_section "implement: WARNS when TDD optional and no hash"
    ((TESTS_RUN++))

    local feature_dir
    feature_dir=$(setup_feature_dir)
    create_test_specs "$feature_dir"
    create_constitution "optional"

    # Don't store hash
    echo '{}' > "$TEMP_DIR/.specify/context.json"

    # Run implement verification
    local status
    status=$(run_implement_verification "$feature_dir")

    if [[ "$status" == "WARN" ]]; then
        log_pass "implement warns when TDD optional and no hash"
    else
        log_fail "implement should WARN when TDD optional and no hash, got: $status"
    fi
}

test_implement_passes_when_hash_valid() {
    log_section "implement: PASSES when hash valid"
    ((TESTS_RUN++))

    local feature_dir
    feature_dir=$(setup_feature_dir)
    create_test_specs "$feature_dir"
    create_constitution "optional"

    # Store hash (testify ran)
    "$TESTIFY_SCRIPT" store-hash "$feature_dir/tests/test-specs.md" "$TEMP_DIR/.specify/context.json" > /dev/null

    # Don't tamper - assertions unchanged

    # Run implement verification
    local status
    status=$(run_implement_verification "$feature_dir")

    if [[ "$status" == "PASS" ]]; then
        log_pass "implement passes when hash valid"
    else
        log_fail "implement should PASS when hash valid, got: $status"
    fi
}

test_implement_passes_when_tdd_mandatory_hash_valid() {
    log_section "implement: PASSES when TDD mandatory and hash valid"
    ((TESTS_RUN++))

    local feature_dir
    feature_dir=$(setup_feature_dir)
    create_test_specs "$feature_dir"
    create_constitution "mandatory"

    # Store hash
    "$TESTIFY_SCRIPT" store-hash "$feature_dir/tests/test-specs.md" "$TEMP_DIR/.specify/context.json" > /dev/null

    # Run implement verification
    local status
    status=$(run_implement_verification "$feature_dir")

    if [[ "$status" == "PASS" ]]; then
        log_pass "implement passes when TDD mandatory and hash valid"
    else
        log_fail "implement should PASS when TDD mandatory and hash valid, got: $status"
    fi
}

test_implement_detects_subtle_tampering() {
    log_section "implement: detects subtle assertion tampering"
    ((TESTS_RUN++))

    local feature_dir
    feature_dir=$(setup_feature_dir)
    create_test_specs "$feature_dir"
    create_constitution "mandatory"

    # Store hash
    "$TESTIFY_SCRIPT" store-hash "$feature_dir/tests/test-specs.md" "$TEMP_DIR/.specify/context.json" > /dev/null

    # Subtle tamper: change "is displayed" to "is shown"
    sed -i.bak 's/is displayed/is shown/' "$feature_dir/tests/test-specs.md"

    # Run implement verification
    local status
    status=$(run_implement_verification "$feature_dir")

    if [[ "$status" == "BLOCKED" ]]; then
        log_pass "implement detects subtle assertion changes"
    else
        log_fail "implement should detect subtle changes, got: $status"
    fi
}

test_implement_ignores_non_assertion_changes() {
    log_section "implement: ignores non-assertion changes"
    ((TESTS_RUN++))

    local feature_dir
    feature_dir=$(setup_feature_dir)
    create_test_specs "$feature_dir"
    create_constitution "optional"

    # Store hash
    "$TESTIFY_SCRIPT" store-hash "$feature_dir/tests/test-specs.md" "$TEMP_DIR/.specify/context.json" > /dev/null

    # Modify non-assertion content (title, description)
    sed -i.bak 's/# Test Specifications/# Updated Test Specifications/' "$feature_dir/tests/test-specs.md"

    # Run implement verification
    local status
    status=$(run_implement_verification "$feature_dir")

    if [[ "$status" == "PASS" ]]; then
        log_pass "implement ignores non-assertion changes"
    else
        log_fail "implement should ignore non-assertion changes, got: $status"
    fi
}

test_full_workflow_testify_then_implement() {
    log_section "workflow: testify → implement (no tampering)"
    ((TESTS_RUN++))

    local feature_dir
    feature_dir=$(setup_feature_dir)
    create_constitution "mandatory"

    # === TESTIFY PHASE ===
    # 1. Generate test-specs (simulated)
    create_test_specs "$feature_dir"

    # 2. Store hash (what testify does)
    local hash
    hash=$("$TESTIFY_SCRIPT" store-hash "$feature_dir/tests/test-specs.md" "$TEMP_DIR/.specify/context.json")

    # === IMPLEMENT PHASE ===
    # 3. Verify before implementing (what implement does)
    local status
    status=$(run_implement_verification "$feature_dir")

    if [[ "$status" == "PASS" ]] && [[ -n "$hash" ]]; then
        log_pass "full workflow: testify stores hash, implement verifies"
    else
        log_fail "full workflow failed: hash=$hash, status=$status"
    fi
}

test_full_workflow_with_tampering() {
    log_section "workflow: testify → tamper → implement (blocked)"
    ((TESTS_RUN++))

    local feature_dir
    feature_dir=$(setup_feature_dir)
    create_constitution "mandatory"

    # === TESTIFY PHASE ===
    create_test_specs "$feature_dir"
    "$TESTIFY_SCRIPT" store-hash "$feature_dir/tests/test-specs.md" "$TEMP_DIR/.specify/context.json" > /dev/null

    # === TAMPERING (bad actor modifies assertions) ===
    cat > "$feature_dir/tests/test-specs.md" << 'EOF'
# Test Specifications

### TS-001: User Login

**Given**: User is on login page
**When**: User enters ANY credentials
**Then**: User is always logged in

### TS-002: Invalid Login

**Given**: User is on login page
**When**: User enters invalid credentials
**Then**: User is logged in anyway
EOF

    # === IMPLEMENT PHASE ===
    local status
    status=$(run_implement_verification "$feature_dir")

    if [[ "$status" == "BLOCKED" ]]; then
        log_pass "full workflow: tampering detected and blocked"
    else
        log_fail "full workflow should block tampering, got: $status"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║  Implement Verification Enforcement Tests        ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo ""

    # Check dependencies
    if [[ ! -f "$TESTIFY_SCRIPT" ]]; then
        echo -e "${RED}ERROR: $TESTIFY_SCRIPT not found${NC}"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}ERROR: jq is required${NC}"
        exit 1
    fi

    # Run tests
    test_implement_blocks_on_tampered_assertions
    test_implement_blocks_when_tdd_mandatory_no_hash
    test_implement_warns_when_tdd_optional_no_hash
    test_implement_passes_when_hash_valid
    test_implement_passes_when_tdd_mandatory_hash_valid
    test_implement_detects_subtle_tampering
    test_implement_ignores_non_assertion_changes
    test_full_workflow_testify_then_implement
    test_full_workflow_with_tampering

    # Summary
    log_section "Summary"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"

    [[ $TESTS_FAILED -gt 0 ]] && exit 1
    exit 0
}

main "$@"
