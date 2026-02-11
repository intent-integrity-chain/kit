#!/usr/bin/env bats
# Tests for pre-commit-hook.sh

load 'test_helper'

HOOK_SCRIPT="$SCRIPTS_DIR/pre-commit-hook.sh"
TESTIFY_SCRIPT="$SCRIPTS_DIR/testify-tdd.sh"

setup() {
    setup_test_dir

    # Copy IIKit scripts into the test directory so the hook can find them
    mkdir -p "$TEST_DIR/.claude/skills/iikit-core/scripts/bash"
    cp "$SCRIPTS_DIR/common.sh" "$TEST_DIR/.claude/skills/iikit-core/scripts/bash/"
    cp "$SCRIPTS_DIR/testify-tdd.sh" "$TEST_DIR/.claude/skills/iikit-core/scripts/bash/"
    cp "$HOOK_SCRIPT" "$TEST_DIR/.claude/skills/iikit-core/scripts/bash/"

    # Install the hook
    mkdir -p "$TEST_DIR/.git/hooks"
    cp "$HOOK_SCRIPT" "$TEST_DIR/.git/hooks/pre-commit"
    chmod +x "$TEST_DIR/.git/hooks/pre-commit"

    # Commit the scripts so they're available
    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit -m "add iikit scripts" >/dev/null 2>&1
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Fast path tests
# =============================================================================

@test "hook: exit 0 when no test-specs.md staged" {
    # Stage a regular file
    echo "hello" > "$TEST_DIR/README.md"
    git -C "$TEST_DIR" add README.md

    # Commit should succeed (hook exits 0)
    run git -C "$TEST_DIR" commit -m "add readme"
    [ "$status" -eq 0 ]
}

@test "hook: exit 0 when no files staged" {
    # Nothing staged — git commit will fail, but not because of hook
    echo "hello" > "$TEST_DIR/some-file.txt"
    # Don't stage it — commit will fail with "nothing to commit"
    # We test the hook directly instead
    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
}

# =============================================================================
# Valid hash tests
# =============================================================================

@test "hook: exit 0 when test-specs.md staged with valid hash" {
    # Create a feature with test-specs.md
    mkdir -p "$TEST_DIR/specs/001-feature/tests"
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
# Test Specifications

**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected to login page
EOF

    # Store the hash in context.json using testify-tdd.sh

    "$TESTIFY_SCRIPT" store-hash "$TEST_DIR/specs/001-feature/tests/test-specs.md" "$TEST_DIR/specs/001-feature/context.json" > /dev/null

    # Stage the test-specs.md
    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md specs/001-feature/context.json
    git -C "$TEST_DIR" commit -m "add test specs" >/dev/null 2>&1

    # Now re-stage the same unchanged file (via a no-op edit)
    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md

    # Hook should pass
    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
}

# =============================================================================
# Tampered assertions tests
# =============================================================================

@test "hook: exit 1 when assertions tampered (hash mismatch)" {
    # Create a feature with test-specs.md
    mkdir -p "$TEST_DIR/specs/001-feature/tests"
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected to login page
EOF

    # Store the hash

    "$TESTIFY_SCRIPT" store-hash "$TEST_DIR/specs/001-feature/tests/test-specs.md" "$TEST_DIR/specs/001-feature/context.json" > /dev/null

    # Commit the original
    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit -m "original test specs" >/dev/null 2>&1

    # Tamper with assertions
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a user is logged in
**When**: they click logout
**Then**: they see a success message instead
EOF

    # Stage the tampered file
    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md

    # Hook should BLOCK
    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 1 ]
    assert_contains "$output" "ASSERTION INTEGRITY CHECK FAILED"
}

# =============================================================================
# Missing hash tests
# =============================================================================

@test "hook: exit 0 when no context.json exists" {
    # Create test-specs.md without storing a hash
    mkdir -p "$TEST_DIR/specs/001-feature/tests"
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a test
**Then**: a result
EOF

    # No specs/001-feature/context.json exists
    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md

    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
}

@test "hook: warns when TDD mandatory and no hash" {
    # Create constitution with mandatory TDD
    cat > "$TEST_DIR/CONSTITUTION.md" << 'EOF'
# Constitution
TDD MUST be used for all features.
EOF
    git -C "$TEST_DIR" add CONSTITUTION.md
    git -C "$TEST_DIR" commit -m "add constitution" >/dev/null 2>&1

    # Create test-specs.md without storing a hash
    mkdir -p "$TEST_DIR/specs/001-feature/tests"
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a test
**Then**: a result
EOF

    # No context.json hash — but should still allow (initial commit)
    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md

    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
    assert_contains "$output" "Warning"
    assert_contains "$output" "no stored assertion hash"
}

# =============================================================================
# Non-assertion changes tests
# =============================================================================

@test "hook: ignores non-assertion changes (title edits)" {
    # Create test-specs.md with assertions
    mkdir -p "$TEST_DIR/specs/001-feature/tests"
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
# Test Specifications
## Section One

**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected to login page
EOF

    # Store the hash

    "$TESTIFY_SCRIPT" store-hash "$TEST_DIR/specs/001-feature/tests/test-specs.md" "$TEST_DIR/specs/001-feature/context.json" > /dev/null

    # Commit the original
    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit -m "original" >/dev/null 2>&1

    # Change only the title (not assertions)
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
# Updated Test Specifications
## Updated Section

**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected to login page
EOF

    # Stage the change
    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md

    # Hook should pass — assertions unchanged
    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
}

# =============================================================================
# Scripts not found tests
# =============================================================================

@test "hook: exit 0 with warning when scripts directory not found" {
    # Remove all IIKit script directories
    rm -rf "$TEST_DIR/.claude"
    rm -rf "$TEST_DIR/.tessl"
    rm -rf "$TEST_DIR/.codex"

    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit -m "remove scripts" >/dev/null 2>&1

    # Create a test-specs.md and stage it
    mkdir -p "$TEST_DIR/specs/001-feature/tests"
    echo "**Given**: test" > "$TEST_DIR/specs/001-feature/tests/test-specs.md"
    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md

    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
    assert_contains "$output" "Warning"
}
