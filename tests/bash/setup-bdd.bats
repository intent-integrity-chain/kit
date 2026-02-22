#!/usr/bin/env bats
# Tests for setup-bdd.sh — BDD Framework Scaffolding

load 'test_helper'

SETUP_BDD_SCRIPT="$SCRIPTS_DIR/setup-bdd.sh"

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Framework detection from plan.md keywords
# =============================================================================

@test "detect: pytest-bdd from Python + pytest plan" {
    mkdir -p "$TEST_DIR/tests/features"
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: Python 3.12
**Testing**: pytest, pytest-bdd
EOF

    # Remove features dir so we get SCAFFOLDED (not ALREADY_SCAFFOLDED)
    rm -rf "$TEST_DIR/tests/features" "$TEST_DIR/tests/step_definitions"

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_json_field "$result" "framework" "pytest-bdd"
    assert_json_field "$result" "language" "python"
}

@test "detect: behave from Python + behave plan" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: Python 3.11
**Testing**: behave
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_json_field "$result" "framework" "behave"
    assert_json_field "$result" "language" "python"
}

@test "detect: cucumber from JavaScript plan" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: TypeScript 5.x
**Primary Dependencies**: Express
**Testing**: @cucumber/cucumber, Jest
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_json_field "$result" "framework" "@cucumber/cucumber"
    assert_json_field "$result" "language" "javascript"
}

@test "detect: godog from Go plan" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: Go 1.22
**Testing**: godog, go test
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_json_field "$result" "framework" "godog"
    assert_json_field "$result" "language" "go"
}

@test "detect: cucumber-jvm-maven from Java + Maven plan" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: Java 21
**Build**: Maven (pom.xml)
**Testing**: JUnit 5, Cucumber
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_json_field "$result" "framework" "cucumber-jvm-maven"
    assert_json_field "$result" "language" "java"
}

@test "detect: cucumber-jvm-gradle from Java + Gradle plan" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: Java 21
**Build**: Gradle
**Testing**: JUnit 5, Cucumber
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_json_field "$result" "framework" "cucumber-jvm-gradle"
    assert_json_field "$result" "language" "java"
}

@test "detect: cucumber-rs from Rust plan" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: Rust 1.75
**Testing**: cucumber-rs
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_json_field "$result" "framework" "cucumber-rs"
    assert_json_field "$result" "language" "rust"
}

@test "detect: reqnroll from C# plan" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: C# .NET 8
**Testing**: Reqnroll, NUnit
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_json_field "$result" "framework" "reqnroll"
    assert_json_field "$result" "language" "csharp"
}

# =============================================================================
# SCAFFOLDED response — directory creation
# =============================================================================

@test "scaffold: creates features and step_definitions directories" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
## Technical Context
**Language/Version**: Python 3.12
**Testing**: pytest-bdd
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")

    # Directories should exist
    [[ -d "$TEST_DIR/tests/features" ]]
    [[ -d "$TEST_DIR/tests/step_definitions" ]]

    # Status should be SCAFFOLDED
    assert_json_field "$result" "status" "SCAFFOLDED"
}

@test "scaffold: directories_created lists created dirs" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
## Technical Context
**Testing**: pytest-bdd
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")

    # directories_created should be a non-empty array
    local dir_count
    dir_count=$(echo "$result" | jq '.directories_created | length')
    [[ "$dir_count" -gt 0 ]]
}

# =============================================================================
# ALREADY_SCAFFOLDED response — idempotency
# =============================================================================

@test "idempotent: second run returns ALREADY_SCAFFOLDED" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
## Technical Context
**Testing**: pytest-bdd
EOF

    # First run: scaffold
    "$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md" >/dev/null

    # Second run: should detect existing scaffolding
    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_json_field "$result" "status" "ALREADY_SCAFFOLDED"
}

@test "idempotent: ALREADY_SCAFFOLDED has empty directories_created" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
## Technical Context
**Testing**: pytest-bdd
EOF

    # First run
    "$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md" >/dev/null

    # Second run
    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")

    local dir_count
    dir_count=$(echo "$result" | jq '.directories_created | length')
    [[ "$dir_count" -eq 0 ]]
}

@test "idempotent: ALREADY_SCAFFOLDED has empty packages_installed" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
## Technical Context
**Testing**: pytest-bdd
EOF

    # First run
    "$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md" >/dev/null

    # Second run
    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")

    local pkg_count
    pkg_count=$(echo "$result" | jq '.packages_installed | length')
    [[ "$pkg_count" -eq 0 ]]
}

# =============================================================================
# NO_FRAMEWORK mode
# =============================================================================

@test "no-framework: returns NO_FRAMEWORK when no tech stack detected" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Implementation Plan

## Summary

This is a documentation-only feature with no code.
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_json_field "$result" "status" "NO_FRAMEWORK"
}

@test "no-framework: framework is null in JSON" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Plan with no tech stack
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")

    local fw
    fw=$(echo "$result" | jq -r '.framework')
    [[ "$fw" == "null" ]]
}

@test "no-framework: language is unknown" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Plan with no tech stack
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_json_field "$result" "language" "unknown"
}

@test "no-framework: message is present" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Plan with no tech stack
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")

    local msg
    msg=$(echo "$result" | jq -r '.message')
    assert_contains "$msg" "No BDD framework detected"
}

@test "no-framework: still creates directories" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Plan with no tech stack
EOF

    "$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md" >/dev/null

    [[ -d "$TEST_DIR/tests/features" ]]
    [[ -d "$TEST_DIR/tests/step_definitions" ]]
}

@test "no-framework: handles missing plan.md gracefully" {
    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/nonexistent-plan.md")
    assert_json_field "$result" "status" "NO_FRAMEWORK"
}

# =============================================================================
# JSON output schema validation
# =============================================================================

@test "json-schema: SCAFFOLDED has all required fields" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
## Technical Context
**Testing**: pytest-bdd
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")

    # Validate all fields exist
    echo "$result" | jq -e '.status' >/dev/null
    echo "$result" | jq -e '.framework' >/dev/null
    echo "$result" | jq -e '.language' >/dev/null
    echo "$result" | jq -e '.directories_created' >/dev/null
    echo "$result" | jq -e '.packages_installed' >/dev/null
    echo "$result" | jq -e '.config_files_created' >/dev/null
}

@test "json-schema: ALREADY_SCAFFOLDED has all required fields" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
## Technical Context
**Testing**: pytest-bdd
EOF

    # First run
    "$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md" >/dev/null

    # Second run
    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")

    echo "$result" | jq -e '.status' >/dev/null
    echo "$result" | jq -e '.framework' >/dev/null
    echo "$result" | jq -e '.language' >/dev/null
    echo "$result" | jq -e '.directories_created' >/dev/null
    echo "$result" | jq -e '.packages_installed' >/dev/null
    echo "$result" | jq -e '.config_files_created' >/dev/null
}

@test "json-schema: NO_FRAMEWORK has required fields" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Docs only
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")

    echo "$result" | jq -e 'has("status")' >/dev/null
    echo "$result" | jq -e 'has("framework")' >/dev/null
    echo "$result" | jq -e 'has("language")' >/dev/null
    echo "$result" | jq -e 'has("message")' >/dev/null
}

@test "json-schema: output is valid JSON" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
## Technical Context
**Testing**: pytest-bdd
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")

    # jq will fail if not valid JSON
    echo "$result" | jq . >/dev/null
}

@test "json-schema: config_files_created is empty array" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
## Technical Context
**Testing**: pytest-bdd
EOF

    result=$("$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")

    local cfg_count
    cfg_count=$(echo "$result" | jq '.config_files_created | length')
    [[ "$cfg_count" -eq 0 ]]
}

# =============================================================================
# Exit code behavior
# =============================================================================

@test "exit-code: SCAFFOLDED returns 0" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
## Technical Context
**Testing**: behave
EOF

    run "$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md"
    [[ "$status" -eq 0 ]]
}

@test "exit-code: ALREADY_SCAFFOLDED returns 0" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
## Technical Context
**Testing**: behave
EOF

    "$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md" >/dev/null

    run "$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md"
    [[ "$status" -eq 0 ]]
}

@test "exit-code: NO_FRAMEWORK returns 0" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Docs only
EOF

    run "$SETUP_BDD_SCRIPT" --json "$TEST_DIR/tests/features" "$TEST_DIR/plan.md"
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# Human-readable output (non-JSON mode)
# =============================================================================

@test "human: SCAFFOLDED prints framework info" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
## Technical Context
**Testing**: pytest-bdd
EOF

    result=$("$SETUP_BDD_SCRIPT" "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_contains "$result" "pytest-bdd"
    assert_contains "$result" "Scaffolded"
}

@test "human: NO_FRAMEWORK prints warning" {
    cat > "$TEST_DIR/plan.md" <<'EOF'
# Docs only
EOF

    result=$("$SETUP_BDD_SCRIPT" "$TEST_DIR/tests/features" "$TEST_DIR/plan.md")
    assert_contains "$result" "WARNING"
    assert_contains "$result" "No BDD framework detected"
}
