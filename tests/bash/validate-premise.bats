#!/usr/bin/env bats
# Tests for validate-premise.sh

load 'test_helper'

VALIDATE_SCRIPT="$SCRIPTS_DIR/validate-premise.sh"

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Helper: create a good PREMISE.md in the test directory
# =============================================================================

create_good_premise() {
    cp "$FIXTURES_DIR/premise-good.md" "$TEST_DIR/PREMISE.md"
}

create_bad_premise() {
    cp "$FIXTURES_DIR/premise-bad.md" "$TEST_DIR/PREMISE.md"
}

create_empty_sections_premise() {
    cp "$FIXTURES_DIR/premise-empty-sections.md" "$TEST_DIR/PREMISE.md"
}

# =============================================================================
# PASS tests
# =============================================================================

@test "validate-premise: validates complete PREMISE.md (PASS)" {
    create_good_premise

    run "$VALIDATE_SCRIPT" --json "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"status":"PASS"'
}

@test "validate-premise: passes with all 5 sections filled" {
    create_good_premise

    run "$VALIDATE_SCRIPT" --json "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"sections_found":5'
    assert_contains "$output" '"sections_required":5'
    assert_contains "$output" '"placeholders_remaining":0'
}

@test "validate-premise: exit code 0 for PASS" {
    create_good_premise

    run "$VALIDATE_SCRIPT" "$TEST_DIR"
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# FAIL tests
# =============================================================================

@test "validate-premise: fails when PREMISE.md missing" {
    # No PREMISE.md created
    run "$VALIDATE_SCRIPT" --json "$TEST_DIR"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" '"status":"FAIL"'
    assert_contains "$output" "not found"
}

@test "validate-premise: fails when sections missing" {
    create_bad_premise

    run "$VALIDATE_SCRIPT" --json "$TEST_DIR"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" '"status":"FAIL"'
    assert_contains "$output" '"missing_sections"'
    assert_contains "$output" "Why"
    assert_contains "$output" "Domain"
    assert_contains "$output" "Scope"
}

@test "validate-premise: fails when placeholders remain" {
    create_bad_premise

    run "$VALIDATE_SCRIPT" --json "$TEST_DIR"
    [[ "$status" -eq 1 ]]

    # Parse placeholders_remaining from JSON
    placeholders=$(echo "$output" | jq -r '.placeholders_remaining')
    [[ "$placeholders" -gt 0 ]]
}

@test "validate-premise: exit code 1 for FAIL" {
    # No PREMISE.md
    run "$VALIDATE_SCRIPT" "$TEST_DIR"
    [[ "$status" -eq 1 ]]
}

@test "validate-premise: handles PREMISE.md with only comments (empty sections)" {
    create_empty_sections_premise

    run "$VALIDATE_SCRIPT" --json "$TEST_DIR"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" '"status":"FAIL"'
    assert_contains "$output" "no content"
}

# =============================================================================
# JSON output schema tests
# =============================================================================

@test "validate-premise: JSON output has correct schema on PASS" {
    create_good_premise

    result=$("$VALIDATE_SCRIPT" --json "$TEST_DIR")

    # Validate JSON is parseable
    echo "$result" | jq . >/dev/null

    # Check all required fields exist
    echo "$result" | jq -e '.status' >/dev/null
    echo "$result" | jq -e '.sections_found' >/dev/null
    echo "$result" | jq -e '.sections_required' >/dev/null
    echo "$result" | jq -e '.placeholders_remaining' >/dev/null
    echo "$result" | jq -e '.missing_sections' >/dev/null
    echo "$result" | jq -e '.details' >/dev/null
}

@test "validate-premise: JSON output has correct schema on FAIL" {
    create_bad_premise

    run "$VALIDATE_SCRIPT" --json "$TEST_DIR"
    [[ "$status" -eq 1 ]]

    # Validate JSON is parseable
    echo "$output" | jq . >/dev/null

    # Check all required fields exist
    echo "$output" | jq -e '.status' >/dev/null
    echo "$output" | jq -e '.sections_found' >/dev/null
    echo "$output" | jq -e '.sections_required' >/dev/null
    echo "$output" | jq -e '.placeholders_remaining' >/dev/null
    echo "$output" | jq -e '.missing_sections' >/dev/null
    echo "$output" | jq -e '.details' >/dev/null
}

@test "validate-premise: JSON output is valid JSON on missing file" {
    run "$VALIDATE_SCRIPT" --json "$TEST_DIR"
    [[ "$status" -eq 1 ]]

    echo "$output" | jq . >/dev/null
}

# =============================================================================
# Text output tests
# =============================================================================

@test "validate-premise: text output shows PASS for valid premise" {
    create_good_premise

    run "$VALIDATE_SCRIPT" "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "PASS"
}

@test "validate-premise: text output shows FAIL for invalid premise" {
    run "$VALIDATE_SCRIPT" "$TEST_DIR"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "FAIL"
}

# =============================================================================
# Help test
# =============================================================================

@test "validate-premise: --help shows usage" {
    run "$VALIDATE_SCRIPT" --help
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage:"
    assert_contains "$output" "--json"
}

# =============================================================================
# Edge cases
# =============================================================================

@test "validate-premise: detects placeholder tokens like [PROJECT_NAME]" {
    cat > "$TEST_DIR/PREMISE.md" <<'EOF'
# [PROJECT_NAME] Premise

## What
A real description of the project.

## Who
Real users.

## Why
Real reason.

## Domain
Real domain.

## Scope
Real scope.
EOF

    run "$VALIDATE_SCRIPT" --json "$TEST_DIR"
    [[ "$status" -eq 1 ]]

    placeholders=$(echo "$output" | jq -r '.placeholders_remaining')
    [[ "$placeholders" -gt 0 ]]
}

@test "validate-premise: does not flag markdown links as placeholders" {
    cat > "$TEST_DIR/PREMISE.md" <<'EOF'
# My Project Premise

## What
A project that uses [this link](https://example.com) for reference.

## Who
Developers who read [docs](https://docs.example.com).

## Why
To solve a real problem.

## Domain
Software development tools.

## Scope
CLI only. No web interface.
EOF

    run "$VALIDATE_SCRIPT" --json "$TEST_DIR"
    [[ "$status" -eq 0 ]]

    placeholders=$(echo "$output" | jq -r '.placeholders_remaining')
    [[ "$placeholders" -eq 0 ]]
}

@test "validate-premise: sections_found counts only present sections" {
    create_bad_premise

    run "$VALIDATE_SCRIPT" --json "$TEST_DIR"

    sections=$(echo "$output" | jq -r '.sections_found')
    [[ "$sections" -eq 2 ]]
}
