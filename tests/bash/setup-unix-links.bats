#!/usr/bin/env bats
# Tests for setup-unix-links.sh

load 'test_helper'

SETUP_SCRIPT="$SCRIPTS_DIR/setup-unix-links.sh"

setup() {
    # Create a clean test directory (don't use setup_test_dir as it creates extra structure)
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    # Create minimal project structure
    mkdir -p .claude/skills
    echo "# Test skill" > .claude/skills/test-skill.md
    echo "# AGENTS.md" > AGENTS.md
}

teardown() {
    cd /
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Helper to run script with project root
run_setup() {
    run "$SETUP_SCRIPT" --project-root "$TEST_DIR" "$@"
}

run_setup_direct() {
    "$SETUP_SCRIPT" --project-root "$TEST_DIR" "$@"
}

# =============================================================================
# Help and usage tests
# =============================================================================

@test "setup-unix-links: --help shows usage" {
    run "$SETUP_SCRIPT" --help
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage"
    assert_contains "$output" "--force"
}

@test "setup-unix-links: -h shows usage" {
    run "$SETUP_SCRIPT" -h
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage"
}

# =============================================================================
# Directory symlink tests
# =============================================================================

@test "setup-unix-links: creates .codex/skills symlink" {
    run_setup
    [[ "$status" -eq 0 ]]
    [[ -L ".codex/skills" ]]
}

@test "setup-unix-links: creates .gemini/skills symlink" {
    run_setup
    [[ "$status" -eq 0 ]]
    [[ -L ".gemini/skills" ]]
}

@test "setup-unix-links: creates .opencode/skills symlink" {
    run_setup
    [[ "$status" -eq 0 ]]
    [[ -L ".opencode/skills" ]]
}

@test "setup-unix-links: directory symlinks point to .claude/skills" {
    run_setup_direct

    # Verify symlinks resolve to same content
    [[ -f ".codex/skills/test-skill.md" ]]
    [[ -f ".gemini/skills/test-skill.md" ]]
    [[ -f ".opencode/skills/test-skill.md" ]]
}

# =============================================================================
# File symlink tests
# =============================================================================

@test "setup-unix-links: creates CLAUDE.md symlink" {
    run_setup
    [[ "$status" -eq 0 ]]
    [[ -L "CLAUDE.md" ]]
}

@test "setup-unix-links: creates GEMINI.md symlink" {
    run_setup
    [[ "$status" -eq 0 ]]
    [[ -L "GEMINI.md" ]]
}

@test "setup-unix-links: file symlinks point to AGENTS.md" {
    run_setup_direct

    # Verify symlinks have same content as AGENTS.md
    [[ "$(cat CLAUDE.md)" == "$(cat AGENTS.md)" ]]
    [[ "$(cat GEMINI.md)" == "$(cat AGENTS.md)" ]]
}

# =============================================================================
# Skip behavior tests
# =============================================================================

@test "setup-unix-links: skips existing symlinks without force" {
    # Create symlinks first
    run_setup_direct

    # Run again
    run_setup
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "SKIP"
}

@test "setup-unix-links: reports existing regular directory as error" {
    mkdir -p .codex/skills
    echo "real file" > .codex/skills/file.txt

    run_setup
    [[ "$status" -ne 0 ]] || assert_contains "$output" "ERROR"
}

# =============================================================================
# Force flag tests
# =============================================================================

@test "setup-unix-links: --force overwrites existing symlinks" {
    # Create symlinks first
    run_setup_direct

    # Run with force
    run_setup --force
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Removing existing link"
    assert_contains "$output" "[OK]"
}

@test "setup-unix-links: -f is alias for --force" {
    # Create symlinks first
    run_setup_direct

    # Run with -f
    run_setup -f
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Removing existing link"
}

# =============================================================================
# Output format tests
# =============================================================================

@test "setup-unix-links: shows success message on completion" {
    run_setup
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Setup complete"
}

@test "setup-unix-links: shows project root in output" {
    run_setup
    assert_contains "$output" "Project root:"
}
