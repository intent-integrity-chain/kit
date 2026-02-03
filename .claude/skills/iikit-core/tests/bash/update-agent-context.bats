#!/usr/bin/env bats
# Tests for update-agent-context.sh

load 'test_helper'

UPDATE_SCRIPT="$SCRIPTS_DIR/update-agent-context.sh"

setup() {
    setup_test_dir

    # Create a complete feature with plan.md
    feature_dir=$(create_mock_feature)

    # Ensure plan.md has the expected format
    cat > "$TEST_DIR/$feature_dir/plan.md" << 'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: Python 3.11
**Primary Dependencies**: FastAPI, SQLAlchemy
**Storage**: PostgreSQL
**Project Type**: web-api

## Architecture
Standard REST API architecture.
EOF

    # Checkout to feature branch
    git checkout -b 001-test-feature >/dev/null 2>&1
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Prerequisite validation tests
# =============================================================================

@test "update-agent-context: fails without plan.md" {
    rm -f specs/001-test-feature/plan.md

    run "$UPDATE_SCRIPT"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "No plan.md found"
}

@test "update-agent-context: succeeds with valid plan.md" {
    run "$UPDATE_SCRIPT"
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# Plan parsing tests
# =============================================================================

@test "update-agent-context: extracts language from plan" {
    run "$UPDATE_SCRIPT"
    assert_contains "$output" "Python"
}

@test "update-agent-context: extracts framework from plan" {
    run "$UPDATE_SCRIPT"
    assert_contains "$output" "FastAPI"
}

@test "update-agent-context: extracts database from plan" {
    run "$UPDATE_SCRIPT"
    assert_contains "$output" "PostgreSQL"
}

# =============================================================================
# Agent file creation tests
# =============================================================================

@test "update-agent-context: creates CLAUDE.md when none exists" {
    rm -f CLAUDE.md GEMINI.md AGENTS.md

    "$UPDATE_SCRIPT"

    [[ -f "CLAUDE.md" ]]
}

@test "update-agent-context: updates existing CLAUDE.md" {
    echo "# Existing Claude file" > CLAUDE.md

    run "$UPDATE_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Updated"
}

@test "update-agent-context: updates all existing agent files" {
    echo "# Claude" > CLAUDE.md
    echo "# Gemini" > GEMINI.md
    echo "# Agents" > AGENTS.md

    run "$UPDATE_SCRIPT"
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# Specific agent tests
# =============================================================================

@test "update-agent-context: claude updates only CLAUDE.md" {
    rm -f CLAUDE.md GEMINI.md AGENTS.md

    run "$UPDATE_SCRIPT" claude
    [[ "$status" -eq 0 ]]
    [[ -f "CLAUDE.md" ]]
}

@test "update-agent-context: gemini updates only GEMINI.md" {
    rm -f CLAUDE.md GEMINI.md AGENTS.md

    run "$UPDATE_SCRIPT" gemini
    [[ "$status" -eq 0 ]]
    [[ -f "GEMINI.md" ]]
}

@test "update-agent-context: codex updates AGENTS.md" {
    rm -f CLAUDE.md GEMINI.md AGENTS.md

    run "$UPDATE_SCRIPT" codex
    [[ "$status" -eq 0 ]]
    [[ -f "AGENTS.md" ]]
}

@test "update-agent-context: rejects unknown agent type" {
    run "$UPDATE_SCRIPT" unknown-agent
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Unknown agent type"
}

# =============================================================================
# Output format tests
# =============================================================================

@test "update-agent-context: shows success message" {
    run "$UPDATE_SCRIPT"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "completed successfully"
}

@test "update-agent-context: shows feature name in output" {
    run "$UPDATE_SCRIPT"
    assert_contains "$output" "001-test-feature"
}

# =============================================================================
# Edge case tests
# =============================================================================

@test "update-agent-context: extracts project type from plan" {
    run "$UPDATE_SCRIPT"
    assert_contains "$output" "web-api"
}

@test "update-agent-context: handles missing template gracefully" {
    # Move template away temporarily
    local template_dir="$SCRIPTS_DIR/../../templates"
    if [[ -f "$template_dir/agent-file-template.md" ]]; then
        mv "$template_dir/agent-file-template.md" "$template_dir/agent-file-template.md.bak"
    fi

    rm -f CLAUDE.md GEMINI.md AGENTS.md

    run "$UPDATE_SCRIPT"

    # Restore template
    if [[ -f "$template_dir/agent-file-template.md.bak" ]]; then
        mv "$template_dir/agent-file-template.md.bak" "$template_dir/agent-file-template.md"
    fi

    # Should fail gracefully when template missing
    [[ "$status" -eq 1 ]] || assert_contains "$output" "Template not found"
}
