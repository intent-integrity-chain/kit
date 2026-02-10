#!/usr/bin/env bash
#
# Tests for pre-commit-hook.sh assertion integrity enforcement
#
# Usage:
#   ./test-pre-commit-hook.sh
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
HOOK_SCRIPT="$SCRIPT_DIR/../scripts/bash/pre-commit-hook.sh"
TESTIFY_SCRIPT="$SCRIPT_DIR/../scripts/bash/testify-tdd.sh"
SCRIPTS_DIR="$SCRIPT_DIR/../scripts/bash"

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)); }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# Create a test project directory with git init and iikit scripts
setup_test_project() {
    local test_dir
    test_dir=$(mktemp -d)

    # Initialize git
    git -C "$test_dir" init . >/dev/null 2>&1
    git -C "$test_dir" config user.email "test@test.com"
    git -C "$test_dir" config user.name "Test"

    # Copy IIKit scripts into the test directory
    mkdir -p "$test_dir/.claude/skills/iikit-core/scripts/bash"
    cp "$SCRIPTS_DIR/common.sh" "$test_dir/.claude/skills/iikit-core/scripts/bash/"
    cp "$SCRIPTS_DIR/testify-tdd.sh" "$test_dir/.claude/skills/iikit-core/scripts/bash/"
    cp "$HOOK_SCRIPT" "$test_dir/.claude/skills/iikit-core/scripts/bash/"

    # Install the hook
    mkdir -p "$test_dir/.git/hooks"
    cp "$HOOK_SCRIPT" "$test_dir/.git/hooks/pre-commit"
    chmod +x "$test_dir/.git/hooks/pre-commit"

    # Create basic structure
    mkdir -p "$test_dir/.specify"
    mkdir -p "$test_dir/specs"

    # Initial commit
    git -C "$test_dir" add -A >/dev/null 2>&1
    git -C "$test_dir" commit -m "initial setup" >/dev/null 2>&1

    echo "$test_dir"
}

cleanup_test_project() {
    local test_dir="$1"
    [[ -n "$test_dir" && -d "$test_dir" ]] && rm -rf "$test_dir"
}

# =============================================================================
# Tests
# =============================================================================

test_no_test_specs_staged() {
    log_section "Fast path: no test-specs.md staged"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(setup_test_project)

    # Stage a regular file
    echo "hello" > "$test_dir/README.md"
    git -C "$test_dir" add README.md

    # Run hook
    cd "$test_dir"
    local exit_code=0
    bash .git/hooks/pre-commit 2>/dev/null || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        log_pass "exit 0 when no test-specs.md staged"
    else
        log_fail "should exit 0, got $exit_code"
    fi

    cleanup_test_project "$test_dir"
}

test_valid_hash() {
    log_section "Valid hash: test-specs.md with matching hash"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(setup_test_project)

    # Create test-specs.md
    mkdir -p "$test_dir/specs/001-feature/tests"
    cat > "$test_dir/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected to login page
EOF

    # Store hash
    "$TESTIFY_SCRIPT" store-hash "$test_dir/specs/001-feature/tests/test-specs.md" "$test_dir/.specify/context.json" > /dev/null

    # Commit everything first
    git -C "$test_dir" add -A >/dev/null 2>&1
    git -C "$test_dir" commit -m "add test specs" >/dev/null 2>&1

    # Re-stage unchanged test-specs.md
    git -C "$test_dir" add specs/001-feature/tests/test-specs.md

    cd "$test_dir"
    local exit_code=0
    bash .git/hooks/pre-commit 2>/dev/null || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        log_pass "exit 0 when hash is valid"
    else
        log_fail "should exit 0, got $exit_code"
    fi

    cleanup_test_project "$test_dir"
}

test_tampered_assertions() {
    log_section "Tampered assertions: hash mismatch blocks commit"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(setup_test_project)

    # Create test-specs.md
    mkdir -p "$test_dir/specs/001-feature/tests"
    cat > "$test_dir/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected to login page
EOF

    # Store hash
    "$TESTIFY_SCRIPT" store-hash "$test_dir/specs/001-feature/tests/test-specs.md" "$test_dir/.specify/context.json" > /dev/null

    # Commit original
    git -C "$test_dir" add -A >/dev/null 2>&1
    git -C "$test_dir" commit -m "original" >/dev/null 2>&1

    # Tamper with assertions
    cat > "$test_dir/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a user is logged in
**When**: they click logout
**Then**: they see a success message instead
EOF

    # Stage tampered file
    git -C "$test_dir" add specs/001-feature/tests/test-specs.md

    cd "$test_dir"
    local exit_code=0
    local output
    output=$(bash .git/hooks/pre-commit 2>&1) || exit_code=$?

    if [[ "$exit_code" -eq 1 ]]; then
        log_pass "exit 1 when assertions tampered"
    else
        log_fail "should exit 1, got $exit_code"
    fi

    cleanup_test_project "$test_dir"
}

test_no_context_json() {
    log_section "Missing context: no context.json allows commit"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(setup_test_project)

    # Create test-specs.md without storing hash
    mkdir -p "$test_dir/specs/001-feature/tests"
    cat > "$test_dir/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a test
**Then**: a result
EOF

    # Remove context.json if exists
    rm -f "$test_dir/.specify/context.json"

    git -C "$test_dir" add specs/001-feature/tests/test-specs.md

    cd "$test_dir"
    local exit_code=0
    bash .git/hooks/pre-commit 2>/dev/null || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        log_pass "exit 0 when no context.json"
    else
        log_fail "should exit 0, got $exit_code"
    fi

    cleanup_test_project "$test_dir"
}

test_tdd_mandatory_no_hash_warns() {
    log_section "TDD mandatory: warns when no hash but allows"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(setup_test_project)

    # Create mandatory TDD constitution
    cat > "$test_dir/CONSTITUTION.md" << 'EOF'
# Constitution
TDD MUST be used for all features.
EOF
    git -C "$test_dir" add CONSTITUTION.md
    git -C "$test_dir" commit -m "add constitution" >/dev/null 2>&1

    # Create test-specs.md without hash
    mkdir -p "$test_dir/specs/001-feature/tests"
    cat > "$test_dir/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a test
**Then**: a result
EOF

    git -C "$test_dir" add specs/001-feature/tests/test-specs.md

    cd "$test_dir"
    local exit_code=0
    local output
    output=$(bash .git/hooks/pre-commit 2>&1) || exit_code=$?

    if [[ "$exit_code" -eq 0 ]] && echo "$output" | grep -qi "warning"; then
        log_pass "exit 0 with warning when TDD mandatory and no hash"
    else
        log_fail "should exit 0 with warning, got exit=$exit_code"
    fi

    cleanup_test_project "$test_dir"
}

test_non_assertion_changes_pass() {
    log_section "Non-assertion changes: title edits pass"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(setup_test_project)

    # Create test-specs.md
    mkdir -p "$test_dir/specs/001-feature/tests"
    cat > "$test_dir/specs/001-feature/tests/test-specs.md" << 'EOF'
# Test Specs
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected
EOF

    # Store hash
    "$TESTIFY_SCRIPT" store-hash "$test_dir/specs/001-feature/tests/test-specs.md" "$test_dir/.specify/context.json" > /dev/null

    git -C "$test_dir" add -A >/dev/null 2>&1
    git -C "$test_dir" commit -m "original" >/dev/null 2>&1

    # Change only the title
    cat > "$test_dir/specs/001-feature/tests/test-specs.md" << 'EOF'
# Updated Title
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected
EOF

    git -C "$test_dir" add specs/001-feature/tests/test-specs.md

    cd "$test_dir"
    local exit_code=0
    bash .git/hooks/pre-commit 2>/dev/null || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        log_pass "exit 0 for non-assertion changes"
    else
        log_fail "should exit 0, got $exit_code"
    fi

    cleanup_test_project "$test_dir"
}

test_scripts_not_found() {
    log_section "Scripts not found: warns and exits 0"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(mktemp -d)

    # Init git but don't copy iikit scripts
    git -C "$test_dir" init . >/dev/null 2>&1
    git -C "$test_dir" config user.email "test@test.com"
    git -C "$test_dir" config user.name "Test"

    # Install hook
    mkdir -p "$test_dir/.git/hooks"
    cp "$HOOK_SCRIPT" "$test_dir/.git/hooks/pre-commit"
    chmod +x "$test_dir/.git/hooks/pre-commit"

    # Initial commit
    echo "init" > "$test_dir/init.txt"
    git -C "$test_dir" add -A >/dev/null 2>&1
    git -C "$test_dir" commit -m "init" >/dev/null 2>&1

    # Stage a test-specs.md
    mkdir -p "$test_dir/specs/001/tests"
    echo "**Given**: test" > "$test_dir/specs/001/tests/test-specs.md"
    git -C "$test_dir" add specs/001/tests/test-specs.md

    cd "$test_dir"
    local exit_code=0
    local output
    output=$(bash .git/hooks/pre-commit 2>&1) || exit_code=$?

    if [[ "$exit_code" -eq 0 ]] && echo "$output" | grep -qi "warning"; then
        log_pass "exit 0 with warning when scripts not found"
    else
        log_fail "should exit 0 with warning, got exit=$exit_code, output: $output"
    fi

    cleanup_test_project "$test_dir"
}

test_multiple_test_specs() {
    log_section "Multiple features: handles multiple test-specs.md files"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(setup_test_project)

    # Create two features
    mkdir -p "$test_dir/specs/001-feature/tests"
    mkdir -p "$test_dir/specs/002-feature/tests"

    # Feature 1 — will have valid hash
    cat > "$test_dir/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: feature 1 state
**Then**: feature 1 result
EOF

    # Feature 2 — no hash (should pass as missing)
    cat > "$test_dir/specs/002-feature/tests/test-specs.md" << 'EOF'
**Given**: feature 2 state
**Then**: feature 2 result
EOF

    # Store hash only for feature 1
    "$TESTIFY_SCRIPT" store-hash "$test_dir/specs/001-feature/tests/test-specs.md" "$test_dir/.specify/context.json" > /dev/null

    git -C "$test_dir" add -A >/dev/null 2>&1
    git -C "$test_dir" commit -m "add features" >/dev/null 2>&1

    # Re-stage both (unchanged)
    git -C "$test_dir" add specs/001-feature/tests/test-specs.md
    git -C "$test_dir" add specs/002-feature/tests/test-specs.md

    cd "$test_dir"
    local exit_code=0
    bash .git/hooks/pre-commit 2>/dev/null || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        log_pass "exit 0 when multiple test-specs.md staged"
    else
        log_fail "should exit 0, got $exit_code"
    fi

    cleanup_test_project "$test_dir"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "========================================"
    echo "  pre-commit-hook.sh Tests"
    echo "========================================"
    echo ""

    # Check scripts exist
    if [[ ! -f "$HOOK_SCRIPT" ]]; then
        echo -e "${RED}ERROR: $HOOK_SCRIPT not found${NC}"
        exit 1
    fi
    if [[ ! -f "$TESTIFY_SCRIPT" ]]; then
        echo -e "${RED}ERROR: $TESTIFY_SCRIPT not found${NC}"
        exit 1
    fi

    # Check dependencies
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}ERROR: jq is required but not installed${NC}"
        exit 1
    fi

    # Save original directory
    local original_dir
    original_dir=$(pwd)

    # Run tests
    test_no_test_specs_staged
    test_valid_hash
    test_tampered_assertions
    test_no_context_json
    test_tdd_mandatory_no_hash_warns
    test_non_assertion_changes_pass
    test_scripts_not_found
    test_multiple_test_specs

    # Return to original directory
    cd "$original_dir"

    # Summary
    log_section "Summary"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"

    [[ $TESTS_FAILED -gt 0 ]] && exit 1
    exit 0
}

main "$@"
