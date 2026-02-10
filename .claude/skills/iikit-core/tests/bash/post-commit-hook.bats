#!/usr/bin/env bats
# Tests for post-commit-hook.sh

load 'test_helper'

POST_HOOK_SCRIPT="$SCRIPTS_DIR/post-commit-hook.sh"
PRE_HOOK_SCRIPT="$SCRIPTS_DIR/pre-commit-hook.sh"
TESTIFY_SCRIPT="$SCRIPTS_DIR/testify-tdd.sh"

setup() {
    setup_test_dir

    # Copy IIKit scripts into the test directory so the hook can find them
    mkdir -p "$TEST_DIR/.claude/skills/iikit-core/scripts/bash"
    cp "$SCRIPTS_DIR/common.sh" "$TEST_DIR/.claude/skills/iikit-core/scripts/bash/"
    cp "$SCRIPTS_DIR/testify-tdd.sh" "$TEST_DIR/.claude/skills/iikit-core/scripts/bash/"
    cp "$POST_HOOK_SCRIPT" "$TEST_DIR/.claude/skills/iikit-core/scripts/bash/"
    cp "$PRE_HOOK_SCRIPT" "$TEST_DIR/.claude/skills/iikit-core/scripts/bash/"

    # Install the post-commit hook
    mkdir -p "$TEST_DIR/.git/hooks"
    cp "$POST_HOOK_SCRIPT" "$TEST_DIR/.git/hooks/post-commit"
    chmod +x "$TEST_DIR/.git/hooks/post-commit"

    # Commit the scripts so they're available
    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit -m "add iikit scripts" >/dev/null 2>&1
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Basic behavior
# =============================================================================

@test "post-commit: no note when no test-specs.md committed" {
    echo "hello" > "$TEST_DIR/README.md"
    git -C "$TEST_DIR" add README.md
    git -C "$TEST_DIR" commit -m "add readme"

    cd "$TEST_DIR"
    run git notes --ref=refs/notes/testify show HEAD
    [ "$status" -ne 0 ]  # No note exists
}

@test "post-commit: creates git note when test-specs.md committed" {
    mkdir -p "$TEST_DIR/specs/001-feature/tests"
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected
EOF

    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md
    git -C "$TEST_DIR" commit -m "add test specs"

    cd "$TEST_DIR"
    run git notes --ref=refs/notes/testify show HEAD
    [ "$status" -eq 0 ]
    assert_contains "$output" "testify-hash:"
}

@test "post-commit: note hash matches computed hash" {
    mkdir -p "$TEST_DIR/specs/001-feature/tests"
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: state A
**When**: action B
**Then**: result C
EOF

    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md
    git -C "$TEST_DIR" commit -m "add test specs"

    cd "$TEST_DIR"
    note_hash=$(git notes --ref=refs/notes/testify show HEAD | grep "^testify-hash:" | cut -d' ' -f2)
    computed_hash=$("$TESTIFY_SCRIPT" compute-hash "$TEST_DIR/specs/001-feature/tests/test-specs.md")

    [[ "$note_hash" == "$computed_hash" ]]
}

@test "post-commit: note includes file path" {
    mkdir -p "$TEST_DIR/specs/001-feature/tests"
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: test
**Then**: result
EOF

    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md
    git -C "$TEST_DIR" commit -m "add test specs"

    cd "$TEST_DIR"
    run git notes --ref=refs/notes/testify show HEAD
    assert_contains "$output" "test-specs-file:"
    assert_contains "$output" "test-specs.md"
}

@test "post-commit: no note for test-specs.md without assertions" {
    mkdir -p "$TEST_DIR/specs/001-feature/tests"
    echo "# Empty test specs" > "$TEST_DIR/specs/001-feature/tests/test-specs.md"

    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md
    git -C "$TEST_DIR" commit -m "empty test specs"

    cd "$TEST_DIR"
    run git notes --ref=refs/notes/testify show HEAD
    [ "$status" -ne 0 ]  # No note
}

# =============================================================================
# End-to-end: post-commit feeds pre-commit
# =============================================================================

@test "e2e: pre-commit blocks tampered assertions using post-commit git note" {
    # Install both hooks
    cp "$PRE_HOOK_SCRIPT" "$TEST_DIR/.git/hooks/pre-commit"
    chmod +x "$TEST_DIR/.git/hooks/pre-commit"

    # Create and commit test-specs.md (post-commit stores git note)
    mkdir -p "$TEST_DIR/specs/001-feature/tests"
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected
EOF

    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md
    git -C "$TEST_DIR" commit -m "testify commit"

    # Verify note was stored
    cd "$TEST_DIR"
    run git notes --ref=refs/notes/testify show HEAD
    [ "$status" -eq 0 ]

    # Tamper with assertions AND remove context.json
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a user is logged in
**When**: they click logout
**Then**: TAMPERED
EOF
    rm -f "$TEST_DIR/.specify/context.json"

    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md

    # Pre-commit should block using the git note
    run git -C "$TEST_DIR" commit -m "tampered"
    [ "$status" -ne 0 ]
}

@test "e2e: pre-commit passes when assertions unchanged (git note validates)" {
    # Install both hooks
    cp "$PRE_HOOK_SCRIPT" "$TEST_DIR/.git/hooks/pre-commit"
    chmod +x "$TEST_DIR/.git/hooks/pre-commit"

    # Create and commit test-specs.md
    mkdir -p "$TEST_DIR/specs/001-feature/tests"
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected
EOF

    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md
    git -C "$TEST_DIR" commit -m "testify commit"

    # Change only non-assertion content
    cat > "$TEST_DIR/specs/001-feature/tests/test-specs.md" << 'EOF'
# Updated Title
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected
EOF
    rm -f "$TEST_DIR/.specify/context.json"

    git -C "$TEST_DIR" add specs/001-feature/tests/test-specs.md

    # Pre-commit should pass — assertions unchanged, git note validates
    run git -C "$TEST_DIR" commit -m "update title only"
    [ "$status" -eq 0 ]
}
