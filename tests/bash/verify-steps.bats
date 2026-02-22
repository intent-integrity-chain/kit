#!/usr/bin/env bats
# Tests for verify-steps.sh

load 'test_helper'

VERIFY_STEPS_SCRIPT="$SCRIPTS_DIR/verify-steps.sh"

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Helper: create a plan.md with a specific tech stack
# =============================================================================

create_plan_with_stack() {
    local plan_file="$1"
    local language="$2"
    local framework="${3:-}"

    cat > "$plan_file" <<EOF
# Implementation Plan

## Technical Context

**Language/Version**: $language
**Primary Dependencies**: $framework
**Testing**: $framework
EOF
}

# =============================================================================
# Helper: create .feature files in a directory
# =============================================================================

create_feature_files() {
    local dir="$1"
    mkdir -p "$dir"

    cat > "$dir/login.feature" <<'FEATURE'
Feature: Login
  Scenario: Valid login
    Given a registered user
    When they enter valid credentials
    Then they are logged in
    And they see the dashboard
FEATURE

    cat > "$dir/logout.feature" <<'FEATURE'
Feature: Logout
  Scenario: User logout
    Given a logged in user
    When they click logout
    Then they are logged out
FEATURE
}

# =============================================================================
# Framework detection tests
# =============================================================================

@test "detect_framework: detects pytest-bdd from plan.md" {
    local plan_file="$TEST_DIR/plan.md"
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"
    create_plan_with_stack "$plan_file" "Python 3.11" "pytest-bdd"

    # Source the script to get the function
    source "$VERIFY_STEPS_SCRIPT"

    result=$(detect_framework "$plan_file" "$features_dir")
    [[ "$result" == "pytest-bdd" ]]
}

@test "detect_framework: detects behave from plan.md" {
    local plan_file="$TEST_DIR/plan.md"
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"
    create_plan_with_stack "$plan_file" "Python 3.11" "behave"

    source "$VERIFY_STEPS_SCRIPT"

    result=$(detect_framework "$plan_file" "$features_dir")
    [[ "$result" == "behave" ]]
}

@test "detect_framework: detects cucumber-js from plan.md" {
    local plan_file="$TEST_DIR/plan.md"
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"
    create_plan_with_stack "$plan_file" "TypeScript 5.x" "@cucumber/cucumber"

    source "$VERIFY_STEPS_SCRIPT"

    result=$(detect_framework "$plan_file" "$features_dir")
    [[ "$result" == "cucumber-js" ]]
}

@test "detect_framework: detects godog from plan.md" {
    local plan_file="$TEST_DIR/plan.md"
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"
    create_plan_with_stack "$plan_file" "Go 1.21" "godog"

    source "$VERIFY_STEPS_SCRIPT"

    result=$(detect_framework "$plan_file" "$features_dir")
    [[ "$result" == "godog" ]]
}

@test "detect_framework: detects cucumber-jvm-maven from plan.md" {
    local plan_file="$TEST_DIR/plan.md"
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"

    cat > "$plan_file" <<'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: Java 17
**Build Tool**: Maven
**Primary Dependencies**: Cucumber, Spring Boot
EOF

    source "$VERIFY_STEPS_SCRIPT"

    result=$(detect_framework "$plan_file" "$features_dir")
    [[ "$result" == "cucumber-jvm-maven" ]]
}

@test "detect_framework: detects cucumber-jvm-gradle from plan.md" {
    local plan_file="$TEST_DIR/plan.md"
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"

    cat > "$plan_file" <<'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: Java 17
**Build Tool**: Gradle
**Primary Dependencies**: Cucumber, Spring Boot
EOF

    source "$VERIFY_STEPS_SCRIPT"

    result=$(detect_framework "$plan_file" "$features_dir")
    [[ "$result" == "cucumber-jvm-gradle" ]]
}

@test "detect_framework: detects cucumber-rs from plan.md" {
    local plan_file="$TEST_DIR/plan.md"
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"
    create_plan_with_stack "$plan_file" "Rust 1.75" "cucumber-rs"

    source "$VERIFY_STEPS_SCRIPT"

    result=$(detect_framework "$plan_file" "$features_dir")
    [[ "$result" == "cucumber-rs" ]]
}

@test "detect_framework: detects reqnroll from plan.md" {
    local plan_file="$TEST_DIR/plan.md"
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"
    create_plan_with_stack "$plan_file" "C# .NET 8" "Reqnroll"

    source "$VERIFY_STEPS_SCRIPT"

    result=$(detect_framework "$plan_file" "$features_dir")
    [[ "$result" == "reqnroll" ]]
}

@test "detect_framework: falls back to language inference for Python" {
    local plan_file="$TEST_DIR/plan.md"
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"

    cat > "$plan_file" <<'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: Python 3.11
**Primary Dependencies**: Flask
EOF

    source "$VERIFY_STEPS_SCRIPT"

    result=$(detect_framework "$plan_file" "$features_dir")
    [[ "$result" == "pytest-bdd" ]]
}

@test "detect_framework: falls back to language inference for TypeScript" {
    local plan_file="$TEST_DIR/plan.md"
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"

    cat > "$plan_file" <<'EOF'
# Implementation Plan

## Technical Context

**Language/Version**: TypeScript 5.x
**Primary Dependencies**: Express
EOF

    source "$VERIFY_STEPS_SCRIPT"

    result=$(detect_framework "$plan_file" "$features_dir")
    [[ "$result" == "cucumber-js" ]]
}

@test "detect_framework: falls back to file extension heuristics" {
    local plan_file="$TEST_DIR/plan-empty.md"
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"
    # Create a plan file with no tech stack info
    echo "# Empty plan" > "$plan_file"

    # Create a Python file near the features directory
    local parent_dir
    parent_dir=$(dirname "$features_dir")
    mkdir -p "$parent_dir/steps"
    touch "$parent_dir/steps/test_steps.py"

    source "$VERIFY_STEPS_SCRIPT"

    result=$(detect_framework "$plan_file" "$features_dir")
    [[ "$result" == "pytest-bdd" ]]
}

@test "detect_framework: returns empty for unrecognized stack" {
    local plan_file="$TEST_DIR/plan-unknown.md"
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"
    echo "# Plan with no recognizable tech" > "$plan_file"

    source "$VERIFY_STEPS_SCRIPT"

    result=$(detect_framework "$plan_file" "$features_dir")
    [[ -z "$result" ]]
}

# =============================================================================
# DEGRADED mode tests
# =============================================================================

@test "DEGRADED: when no framework detected" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"
    echo "# No tech stack info" > "$TEST_DIR/plan.md"

    run "$VERIFY_STEPS_SCRIPT" --json "$features_dir" "$TEST_DIR/plan.md"

    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"status":"DEGRADED"'
    assert_contains "$output" '"framework":null'
    assert_contains "$output" '"total_steps":0'
    assert_contains "$output" '"matched_steps":0'
    assert_contains "$output" '"undefined_steps":0'
    assert_contains "$output" '"pending_steps":0'
}

@test "DEGRADED: when features directory not found" {
    run "$VERIFY_STEPS_SCRIPT" --json "$TEST_DIR/nonexistent" "$TEST_DIR/plan.md"

    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"status":"DEGRADED"'
}

@test "DEGRADED: when no .feature files in directory" {
    local features_dir="$TEST_DIR/features"
    mkdir -p "$features_dir"
    echo "# Not a feature file" > "$features_dir/readme.md"
    echo "# No tech stack info" > "$TEST_DIR/plan.md"

    run "$VERIFY_STEPS_SCRIPT" --json "$features_dir" "$TEST_DIR/plan.md"

    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"status":"DEGRADED"'
}

@test "DEGRADED: exit code is 0" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"
    echo "# No tech stack info" > "$TEST_DIR/plan.md"

    run "$VERIFY_STEPS_SCRIPT" --json "$features_dir" "$TEST_DIR/plan.md"

    [[ "$status" -eq 0 ]]
}

# =============================================================================
# JSON output schema validation
# =============================================================================

@test "JSON output: DEGRADED has all required fields" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"
    echo "# No tech" > "$TEST_DIR/plan.md"

    run "$VERIFY_STEPS_SCRIPT" --json "$features_dir" "$TEST_DIR/plan.md"

    [[ "$status" -eq 0 ]]
    # Validate required fields present
    assert_contains "$output" '"status"'
    assert_contains "$output" '"framework"'
    assert_contains "$output" '"total_steps"'
    assert_contains "$output" '"matched_steps"'
    assert_contains "$output" '"undefined_steps"'
    assert_contains "$output" '"pending_steps"'
    assert_contains "$output" '"details"'
}

@test "JSON output: valid JSON in DEGRADED mode" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"
    echo "# No tech" > "$TEST_DIR/plan.md"

    run "$VERIFY_STEPS_SCRIPT" --json "$features_dir" "$TEST_DIR/plan.md"

    [[ "$status" -eq 0 ]]
    # Validate it parses as JSON (if jq available)
    if command -v jq >/dev/null 2>&1; then
        echo "$output" | jq . >/dev/null 2>&1
    fi
}

@test "JSON output: DEGRADED has null framework" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"
    echo "# No tech" > "$TEST_DIR/plan.md"

    run "$VERIFY_STEPS_SCRIPT" --json "$features_dir" "$TEST_DIR/plan.md"

    assert_contains "$output" '"framework":null'
}

@test "JSON output: DEGRADED has message field" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"
    echo "# No tech" > "$TEST_DIR/plan.md"

    run "$VERIFY_STEPS_SCRIPT" --json "$features_dir" "$TEST_DIR/plan.md"

    assert_contains "$output" '"message"'
}

# =============================================================================
# Step counting tests
# =============================================================================

@test "count_feature_steps: counts steps in feature files" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"

    source "$VERIFY_STEPS_SCRIPT"

    result=$(count_feature_steps "$features_dir")
    # login.feature has 4 steps (Given, When, Then, And)
    # logout.feature has 3 steps (Given, When, Then)
    [[ "$result" -eq 7 ]]
}

@test "count_feature_steps: returns 0 for empty directory" {
    local features_dir="$TEST_DIR/features_empty"
    mkdir -p "$features_dir"

    source "$VERIFY_STEPS_SCRIPT"

    result=$(count_feature_steps "$features_dir")
    [[ "$result" -eq 0 ]]
}

@test "count_feature_steps: returns 0 for nonexistent directory" {
    source "$VERIFY_STEPS_SCRIPT"

    result=$(count_feature_steps "$TEST_DIR/nonexistent")
    [[ "$result" -eq 0 ]]
}

# =============================================================================
# get_dry_run_command tests
# =============================================================================

@test "get_dry_run_command: returns correct command for pytest-bdd" {
    source "$VERIFY_STEPS_SCRIPT"

    result=$(get_dry_run_command "pytest-bdd" "$TEST_DIR/features")
    assert_contains "$result" "pytest --collect-only"
}

@test "get_dry_run_command: returns correct command for behave" {
    source "$VERIFY_STEPS_SCRIPT"

    result=$(get_dry_run_command "behave" "$TEST_DIR/features")
    assert_contains "$result" "behave --dry-run --strict"
}

@test "get_dry_run_command: returns correct command for cucumber-js" {
    source "$VERIFY_STEPS_SCRIPT"

    result=$(get_dry_run_command "cucumber-js" "$TEST_DIR/features")
    assert_contains "$result" "npx cucumber-js --dry-run --strict"
}

@test "get_dry_run_command: returns correct command for godog" {
    source "$VERIFY_STEPS_SCRIPT"

    result=$(get_dry_run_command "godog" "$TEST_DIR/features")
    assert_contains "$result" "godog --strict --no-colors --dry-run"
}

@test "get_dry_run_command: returns correct command for cucumber-jvm-maven" {
    source "$VERIFY_STEPS_SCRIPT"

    result=$(get_dry_run_command "cucumber-jvm-maven" "$TEST_DIR/features")
    assert_contains "$result" "mvn test"
    assert_contains "$result" "dry-run"
}

@test "get_dry_run_command: returns correct command for cucumber-jvm-gradle" {
    source "$VERIFY_STEPS_SCRIPT"

    result=$(get_dry_run_command "cucumber-jvm-gradle" "$TEST_DIR/features")
    assert_contains "$result" "gradle test"
    assert_contains "$result" "dry-run"
}

@test "get_dry_run_command: returns correct command for cucumber-rs" {
    source "$VERIFY_STEPS_SCRIPT"

    result=$(get_dry_run_command "cucumber-rs" "$TEST_DIR/features")
    assert_contains "$result" "cargo test"
}

@test "get_dry_run_command: returns correct command for reqnroll" {
    source "$VERIFY_STEPS_SCRIPT"

    result=$(get_dry_run_command "reqnroll" "$TEST_DIR/features")
    assert_contains "$result" "dotnet test"
    assert_contains "$result" "REQNROLL_DRY_RUN"
}

@test "get_dry_run_command: returns empty for unknown framework" {
    source "$VERIFY_STEPS_SCRIPT"

    result=$(get_dry_run_command "unknown-framework" "$TEST_DIR/features")
    [[ -z "$result" ]]
}

# =============================================================================
# parse_results tests (mocked dry-run output)
# =============================================================================

@test "parse_results: PASS when no undefined steps in pytest-bdd output" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"

    source "$VERIFY_STEPS_SCRIPT"

    # Simulate clean pytest --collect-only output
    local mock_output="collected 7 items
<Module tests/test_login.py>
  <Function test_valid_login>
<Module tests/test_logout.py>
  <Function test_logout>"

    result=$(parse_results "pytest-bdd" "$mock_output" "$features_dir")
    assert_contains "$result" '"status":"PASS"'
    assert_contains "$result" '"framework":"pytest-bdd"'
    assert_contains "$result" '"undefined_steps":0'
    assert_contains "$result" '"pending_steps":0'
}

@test "parse_results: BLOCKED when undefined steps in behave output" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"

    source "$VERIFY_STEPS_SCRIPT"

    # Simulate behave dry-run with undefined steps
    local mock_output="Feature: Login
  Scenario: Valid login
    Given a registered user ... undefined
    When they enter valid credentials ... undefined"

    result=$(parse_results "behave" "$mock_output" "$features_dir")
    assert_contains "$result" '"status":"BLOCKED"'
    assert_contains "$result" '"framework":"behave"'
    # Should have 2 undefined steps
    assert_contains "$result" '"undefined_steps":2'
}

@test "parse_results: BLOCKED when undefined steps in cucumber-js output" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"

    source "$VERIFY_STEPS_SCRIPT"

    # Simulate cucumber-js dry-run with undefined steps
    local mock_output="1 scenario (1 Undefined)
3 steps (1 Undefined, 2 passed)"

    result=$(parse_results "cucumber-js" "$mock_output" "$features_dir")
    assert_contains "$result" '"status":"BLOCKED"'
    assert_contains "$result" '"framework":"cucumber-js"'
}

@test "parse_results: includes total_steps from feature files" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"

    source "$VERIFY_STEPS_SCRIPT"

    local mock_output="collected 7 items"
    result=$(parse_results "pytest-bdd" "$mock_output" "$features_dir")
    assert_contains "$result" '"total_steps":7'
}

@test "parse_results: matched_steps is total minus undefined minus pending" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"

    source "$VERIFY_STEPS_SCRIPT"

    # behave output with 2 undefined, 1 pending
    local mock_output="Given a registered user ... undefined
When they enter valid credentials ... undefined
Then they are logged in ... pending"

    result=$(parse_results "behave" "$mock_output" "$features_dir")
    # total_steps=7, undefined=2, pending=1 => matched=4
    assert_contains "$result" '"matched_steps":4'
}

# =============================================================================
# Human-readable output tests
# =============================================================================

@test "human-readable: shows status without --json flag" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"
    echo "# No tech" > "$TEST_DIR/plan.md"

    run "$VERIFY_STEPS_SCRIPT" "$features_dir" "$TEST_DIR/plan.md"

    [[ "$status" -eq 0 ]]
    assert_contains "$output" "DEGRADED"
}

# =============================================================================
# Usage error tests
# =============================================================================

@test "error: missing features-dir argument" {
    run "$VERIFY_STEPS_SCRIPT" --json

    [[ "$status" -ne 0 ]]
}

@test "error: missing plan-file argument" {
    run "$VERIFY_STEPS_SCRIPT" --json "$TEST_DIR/features"

    [[ "$status" -ne 0 ]]
}

# =============================================================================
# DEGRADED when framework tool not installed
# =============================================================================

@test "DEGRADED: when framework detected but tool not installed" {
    local features_dir="$TEST_DIR/features"
    create_feature_files "$features_dir"
    create_plan_with_stack "$TEST_DIR/plan.md" "Go 1.21" "godog"

    # godog is very unlikely to be installed in test environment
    run "$VERIFY_STEPS_SCRIPT" --json "$features_dir" "$TEST_DIR/plan.md"

    # Should be DEGRADED if godog not installed, or PASS/BLOCKED if it is
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

    if ! command -v godog >/dev/null 2>&1; then
        assert_contains "$output" '"status":"DEGRADED"'
        assert_contains "$output" '"framework":"godog"'
    fi
}
