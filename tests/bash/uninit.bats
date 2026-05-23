#!/usr/bin/env bats
# Tests for uninit.sh — removes iikit scaffolding before `tessl uninstall`.

load 'test_helper'

UNINIT_SCRIPT="$REPO_ROOT/tiles/intent-integrity-kit/skills/iikit-core/scripts/bash/uninit.sh"
HOOKS_SUBDIR=".git/hooks"

setup() {
    setup_test_dir
    cd "$TEST_DIR" || return 1
}

teardown() {
    cd /
    teardown_test_dir
}

# Helper: install a marker-owned iikit hook in the test repo.
install_marker_hook() {
    local hook="$1"
    local marker="$2"
    cat > "$TEST_DIR/$HOOKS_SUBDIR/$hook" <<EOF
#!/usr/bin/env bash
# $marker
echo iikit-$hook
EOF
    chmod +x "$TEST_DIR/$HOOKS_SUBDIR/$hook"
}

# =============================================================================
# Tile-managed scaffolding removal
# =============================================================================

@test "uninit: removes marker-owned pre-commit hook" {
    install_marker_hook "pre-commit" "IIKIT-PRE-COMMIT"

    "$UNINIT_SCRIPT" --json

    [[ ! -f "$TEST_DIR/$HOOKS_SUBDIR/pre-commit" ]]
}

@test "uninit: removes marker-owned post-commit hook" {
    install_marker_hook "post-commit" "IIKIT-POST-COMMIT"

    "$UNINIT_SCRIPT" --json

    [[ ! -f "$TEST_DIR/$HOOKS_SUBDIR/post-commit" ]]
}

@test "uninit: keeps non-iikit hook untouched" {
    cat > "$TEST_DIR/$HOOKS_SUBDIR/pre-commit" <<'EOF'
#!/usr/bin/env bash
echo user hook
EOF
    chmod +x "$TEST_DIR/$HOOKS_SUBDIR/pre-commit"

    "$UNINIT_SCRIPT" --json

    [[ -f "$TEST_DIR/$HOOKS_SUBDIR/pre-commit" ]]
    grep -q "user hook" "$TEST_DIR/$HOOKS_SUBDIR/pre-commit"
}

@test "uninit: strips iikit chain-call from existing user hook" {
    cat > "$TEST_DIR/$HOOKS_SUBDIR/post-commit" <<'EOF'
#!/usr/bin/env bash
echo user post-commit

# IIKit assertion integrity check
"$(dirname "$0")/iikit-post-commit"
EOF
    chmod +x "$TEST_DIR/$HOOKS_SUBDIR/post-commit"
    install_marker_hook "iikit-post-commit" "IIKIT-POST-COMMIT"

    "$UNINIT_SCRIPT" --json

    [[ -f "$TEST_DIR/$HOOKS_SUBDIR/post-commit" ]]
    ! grep -q "iikit-post-commit" "$TEST_DIR/$HOOKS_SUBDIR/post-commit"
    ! grep -q "IIKit assertion integrity check" "$TEST_DIR/$HOOKS_SUBDIR/post-commit"
    grep -q "echo user post-commit" "$TEST_DIR/$HOOKS_SUBDIR/post-commit"
}

@test "uninit: removes alongside iikit-<hook> file" {
    install_marker_hook "iikit-pre-commit" "IIKIT-PRE-COMMIT"

    "$UNINIT_SCRIPT" --json

    [[ ! -f "$TEST_DIR/$HOOKS_SUBDIR/iikit-pre-commit" ]]
}

@test "uninit: removes .specify directory" {
    mkdir -p "$TEST_DIR/.specify"
    touch "$TEST_DIR/.specify/context.json"

    "$UNINIT_SCRIPT" --json

    [[ ! -d "$TEST_DIR/.specify" ]]
}

@test "uninit: removes TECH.md only when it references an iikit phase" {
    echo "Pre-plan notes referencing /iikit-02-plan" > "$TEST_DIR/TECH.md"

    "$UNINIT_SCRIPT" --json

    [[ ! -f "$TEST_DIR/TECH.md" ]]
}

@test "uninit: preserves TECH.md when it does not reference an iikit phase" {
    echo "Generic technical notes — no iikit content here" > "$TEST_DIR/TECH.md"

    "$UNINIT_SCRIPT" --json

    [[ -f "$TEST_DIR/TECH.md" ]]
}

# =============================================================================
# User-authored content reporting
# =============================================================================

@test "uninit: lists user content but does not delete by default" {
    echo "# Constitution" > "$TEST_DIR/CONSTITUTION.md"
    echo "# Premise" > "$TEST_DIR/PREMISE.md"
    mkdir -p "$TEST_DIR/specs/001-foo"

    result=$("$UNINIT_SCRIPT" --json)

    [[ -f "$TEST_DIR/CONSTITUTION.md" ]]
    [[ -f "$TEST_DIR/PREMISE.md" ]]
    [[ -d "$TEST_DIR/specs/001-foo" ]]
    assert_contains "$result" "CONSTITUTION.md"
    assert_contains "$result" "PREMISE.md"
    assert_contains "$result" "specs"
}

@test "uninit: --remove-user-content deletes user-authored files" {
    echo "# Constitution" > "$TEST_DIR/CONSTITUTION.md"
    echo "# Premise" > "$TEST_DIR/PREMISE.md"
    mkdir -p "$TEST_DIR/specs/001-foo"

    "$UNINIT_SCRIPT" --json --remove-user-content

    [[ ! -f "$TEST_DIR/CONSTITUTION.md" ]]
    [[ ! -f "$TEST_DIR/PREMISE.md" ]]
    [[ ! -d "$TEST_DIR/specs" ]]
}

# =============================================================================
# --dry-run
# =============================================================================

@test "uninit: --dry-run reports without modifying anything" {
    install_marker_hook "pre-commit" "IIKIT-PRE-COMMIT"
    mkdir -p "$TEST_DIR/.specify"

    result=$("$UNINIT_SCRIPT" --json --dry-run)

    [[ -f "$TEST_DIR/$HOOKS_SUBDIR/pre-commit" ]]
    [[ -d "$TEST_DIR/.specify" ]]
    assert_contains "$result" '"dry_run":true'
    assert_contains "$result" ".specify"
}

# =============================================================================
# JSON shape
# =============================================================================

@test "uninit: JSON output includes next_step pointing at tessl uninstall" {
    result=$("$UNINIT_SCRIPT" --json)

    assert_contains "$result" "tessl uninstall tessl-labs/intent-integrity-kit"
}

@test "uninit: --json with no scaffolding still emits a valid envelope" {
    # setup_test_dir creates .specify/, specs/, and CONSTITUTION.md — clear them
    # so the script has nothing to clean up or report.
    rm -rf "$TEST_DIR/.specify" "$TEST_DIR/specs"
    rm -f "$TEST_DIR/CONSTITUTION.md"

    result=$("$UNINIT_SCRIPT" --json)

    assert_contains "$result" '"removed":[]'
    assert_contains "$result" '"user_content":[]'
}

# =============================================================================
# pre-commit.d/ handling
# =============================================================================

@test "uninit: removes IIKit-managed pre-commit.d README and empty dir" {
    mkdir -p "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d"
    cat > "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/README" <<'EOF'
# IIKit pre-commit extension point — IIKIT-PRE-COMMIT-D
EOF

    result=$("$UNINIT_SCRIPT" --json)

    [[ ! -d "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d" ]]
    assert_contains "$result" "pre-commit.d"
}

@test "uninit: preserves user scripts in pre-commit.d and reports them" {
    mkdir -p "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d"
    cat > "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/README" <<'EOF'
# IIKit pre-commit extension point — IIKIT-PRE-COMMIT-D
EOF
    cat > "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/prettier" <<'EOF'
#!/bin/sh
EOF
    chmod +x "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/prettier"

    result=$("$UNINIT_SCRIPT" --json)

    # Our README is gone but the user script and dir remain
    [[ ! -f "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/README" ]]
    [[ -x "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/prettier" ]]
    [[ -d "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d" ]]
    assert_contains "$result" "pre-commit.d/prettier"
}

@test "uninit: reports dotfiles in pre-commit.d/ as user content (not silently removed)" {
    mkdir -p "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d"
    cat > "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/README" <<'EOF'
# IIKit pre-commit extension point — IIKIT-PRE-COMMIT-D
EOF
    : > "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/.keep"

    result=$("$UNINIT_SCRIPT" --json)

    # Dotfile must survive AND be reported as user content; dir is preserved
    [[ -f "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/.keep" ]]
    [[ -d "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d" ]]
    assert_contains "$result" ".keep"
}

@test "uninit: --dry-run on pre-commit.d/ does not double-count managed README" {
    # Clear default user-content setup so user_content reflects only this test's intent
    rm -rf "$TEST_DIR/.specify" "$TEST_DIR/specs"
    rm -f "$TEST_DIR/CONSTITUTION.md"

    mkdir -p "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d"
    cat > "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/README" <<'EOF'
# IIKit pre-commit extension point — IIKIT-PRE-COMMIT-D
EOF

    result=$("$UNINIT_SCRIPT" --json --dry-run)

    # README must appear in `removed` (as planned deletion) but NOT in `user_content`,
    # and the dir itself must show as droppable.
    assert_contains "$result" "pre-commit.d/README"
    assert_contains "$result" '"user_content":[]'
    # Disk state is unchanged in dry-run
    [[ -f "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/README" ]]
    [[ -d "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d" ]]
}

@test "uninit: leaves non-iikit README in pre-commit.d/ alone" {
    mkdir -p "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d"
    cat > "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/README" <<'EOF'
# Custom team docs — not iikit-managed
EOF

    "$UNINIT_SCRIPT" --json

    [[ -f "$TEST_DIR/$HOOKS_SUBDIR/pre-commit.d/README" ]]
}
