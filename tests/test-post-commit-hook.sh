#!/usr/bin/env bash
#
# Tests for post-commit-hook.sh git note storage
#
# Usage:
#   ./test-post-commit-hook.sh
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
POST_HOOK_SCRIPT="$SCRIPT_DIR/../scripts/bash/post-commit-hook.sh"
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
    cp "$POST_HOOK_SCRIPT" "$test_dir/.claude/skills/iikit-core/scripts/bash/"

    # Install the post-commit hook
    mkdir -p "$test_dir/.git/hooks"
    cp "$POST_HOOK_SCRIPT" "$test_dir/.git/hooks/post-commit"
    chmod +x "$test_dir/.git/hooks/post-commit"

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

test_no_test_specs_no_note() {
    log_section "No test-specs.md: no git note created"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(setup_test_project)

    # Commit a regular file
    echo "hello" > "$test_dir/README.md"
    git -C "$test_dir" add README.md
    git -C "$test_dir" commit -m "add readme" >/dev/null 2>&1

    # Check no testify git note exists
    cd "$test_dir"
    local note
    note=$(git notes --ref=refs/notes/testify show HEAD 2>/dev/null) || true

    if [[ -z "$note" ]]; then
        log_pass "no git note when no test-specs.md committed"
    else
        log_fail "should not create git note for non-test-specs commit"
    fi

    cleanup_test_project "$test_dir"
}

test_test_specs_creates_note() {
    log_section "test-specs.md committed: git note created"
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

    git -C "$test_dir" add specs/001-feature/tests/test-specs.md
    git -C "$test_dir" commit -m "add test specs" 2>&1 | cat >/dev/null

    # Check git note exists
    cd "$test_dir"
    local note
    note=$(git notes --ref=refs/notes/testify show HEAD 2>/dev/null) || true

    if echo "$note" | grep -q "^testify-hash:"; then
        log_pass "git note created with testify-hash"
    else
        log_fail "should create git note with testify-hash, got: $note"
    fi

    cleanup_test_project "$test_dir"
}

test_note_hash_matches_content() {
    log_section "Git note hash matches committed content"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(setup_test_project)

    # Create test-specs.md
    mkdir -p "$test_dir/specs/001-feature/tests"
    cat > "$test_dir/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: state A
**When**: action B
**Then**: result C
EOF

    git -C "$test_dir" add specs/001-feature/tests/test-specs.md
    git -C "$test_dir" commit -m "add test specs" 2>&1 | cat >/dev/null

    # Extract note hash
    cd "$test_dir"
    local note_hash
    note_hash=$(git notes --ref=refs/notes/testify show HEAD 2>/dev/null | grep "^testify-hash:" | cut -d' ' -f2)

    # Compute hash directly
    local computed_hash
    computed_hash=$("$TESTIFY_SCRIPT" compute-hash "$test_dir/specs/001-feature/tests/test-specs.md")

    if [[ "$note_hash" == "$computed_hash" ]]; then
        log_pass "note hash matches computed hash"
    else
        log_fail "note hash ($note_hash) should match computed hash ($computed_hash)"
    fi

    cleanup_test_project "$test_dir"
}

test_note_includes_file_path() {
    log_section "Git note includes test-specs-file path"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(setup_test_project)

    mkdir -p "$test_dir/specs/001-feature/tests"
    cat > "$test_dir/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: test
**Then**: result
EOF

    git -C "$test_dir" add specs/001-feature/tests/test-specs.md
    git -C "$test_dir" commit -m "add test specs" 2>&1 | cat >/dev/null

    cd "$test_dir"
    local note
    note=$(git notes --ref=refs/notes/testify show HEAD 2>/dev/null)

    if echo "$note" | grep -q "test-specs-file:.*test-specs.md"; then
        log_pass "note includes file path"
    else
        log_fail "note should include file path, got: $note"
    fi

    cleanup_test_project "$test_dir"
}

test_no_assertions_no_note() {
    log_section "No assertions in test-specs.md: no git note"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(setup_test_project)

    mkdir -p "$test_dir/specs/001-feature/tests"
    echo "# Empty test specs with no Given/When/Then" > "$test_dir/specs/001-feature/tests/test-specs.md"

    git -C "$test_dir" add specs/001-feature/tests/test-specs.md
    git -C "$test_dir" commit -m "add empty test specs" >/dev/null 2>&1

    cd "$test_dir"
    local note
    note=$(git notes --ref=refs/notes/testify show HEAD 2>/dev/null) || true

    if [[ -z "$note" ]]; then
        log_pass "no git note for test-specs without assertions"
    else
        log_fail "should not create note for assertionless test-specs"
    fi

    cleanup_test_project "$test_dir"
}

test_scripts_not_found_silent() {
    log_section "Scripts not found: exits silently"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(mktemp -d)

    git -C "$test_dir" init . >/dev/null 2>&1
    git -C "$test_dir" config user.email "test@test.com"
    git -C "$test_dir" config user.name "Test"

    # Install hook but don't copy scripts
    mkdir -p "$test_dir/.git/hooks"
    cp "$POST_HOOK_SCRIPT" "$test_dir/.git/hooks/post-commit"
    chmod +x "$test_dir/.git/hooks/post-commit"

    echo "init" > "$test_dir/init.txt"
    git -C "$test_dir" add -A >/dev/null 2>&1
    git -C "$test_dir" commit -m "init" >/dev/null 2>&1

    mkdir -p "$test_dir/specs/001/tests"
    echo "**Given**: test" > "$test_dir/specs/001/tests/test-specs.md"
    git -C "$test_dir" add specs/001/tests/test-specs.md

    local exit_code=0
    git -C "$test_dir" commit -m "add specs" >/dev/null 2>&1 || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        log_pass "commit succeeds when scripts not found"
    else
        log_fail "commit should succeed, got exit $exit_code"
    fi

    cleanup_test_project "$test_dir"
}

test_pre_commit_uses_post_commit_note() {
    log_section "End-to-end: pre-commit validates against post-commit git note"
    ((TESTS_RUN++))

    local test_dir
    test_dir=$(setup_test_project)

    local pre_commit_hook="$SCRIPT_DIR/../scripts/bash/pre-commit-hook.sh"

    # Install both hooks
    cp "$pre_commit_hook" "$test_dir/.git/hooks/pre-commit"
    chmod +x "$test_dir/.git/hooks/pre-commit"

    # Create test-specs.md and commit (post-commit stores git note)
    mkdir -p "$test_dir/specs/001-feature/tests"
    cat > "$test_dir/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected
EOF

    git -C "$test_dir" add specs/001-feature/tests/test-specs.md
    git -C "$test_dir" commit -m "testify commit" 2>&1 | cat >/dev/null

    # Verify git note was stored
    cd "$test_dir"
    local note
    note=$(git notes --ref=refs/notes/testify show HEAD 2>/dev/null) || true
    if [[ -z "$note" ]]; then
        log_fail "post-commit should have stored a git note"
        cleanup_test_project "$test_dir"
        return
    fi

    # Now tamper with assertions AND context.json (simulating agent bypassing context)
    cat > "$test_dir/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a user is logged in
**When**: they click logout
**Then**: TAMPERED assertion here
EOF

    # Even without context.json, git note should catch it
    rm -f "$test_dir/.specify/context.json"

    git -C "$test_dir" add specs/001-feature/tests/test-specs.md

    local exit_code=0
    git -C "$test_dir" commit -m "tampered" 2>&1 | cat >/dev/null || exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        log_pass "pre-commit blocks tampered assertions using git note from post-commit"
    else
        log_fail "should block tampered assertions via git note"
    fi

    cleanup_test_project "$test_dir"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "========================================"
    echo "  post-commit-hook.sh Tests"
    echo "========================================"
    echo ""

    if [[ ! -f "$POST_HOOK_SCRIPT" ]]; then
        echo -e "${RED}ERROR: $POST_HOOK_SCRIPT not found${NC}"
        exit 1
    fi
    if [[ ! -f "$TESTIFY_SCRIPT" ]]; then
        echo -e "${RED}ERROR: $TESTIFY_SCRIPT not found${NC}"
        exit 1
    fi
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}ERROR: jq is required but not installed${NC}"
        exit 1
    fi

    local original_dir
    original_dir=$(pwd)

    test_no_test_specs_no_note
    test_test_specs_creates_note
    test_note_hash_matches_content
    test_note_includes_file_path
    test_no_assertions_no_note
    test_scripts_not_found_silent
    test_pre_commit_uses_post_commit_note

    cd "$original_dir"

    log_section "Summary"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"

    [[ $TESTS_FAILED -gt 0 ]] && exit 1
    exit 0
}

main "$@"
