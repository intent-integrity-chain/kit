#!/usr/bin/env bats
# Tests for verify-step-quality.sh

load 'test_helper'

VERIFY_SCRIPT="$SCRIPTS_DIR/verify-step-quality.sh"

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# Argument validation
# =============================================================================

@test "exits with error when no arguments provided" {
    run "$VERIFY_SCRIPT"
    [[ "$status" -ne 0 ]]
}

@test "exits with error when only directory provided" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/good"
    [[ "$status" -ne 0 ]]
}

@test "exits with error for nonexistent directory (json mode)" {
    run "$VERIFY_SCRIPT" --json /nonexistent python
    [[ "$status" -ne 0 ]]
    assert_contains "$output" '"status":"ERROR"'
}

@test "exits with error for nonexistent directory (text mode)" {
    run "$VERIFY_SCRIPT" /nonexistent python
    [[ "$status" -ne 0 ]]
}

# =============================================================================
# Python AST analysis - PASS cases
# =============================================================================

@test "python: PASS for good step definitions" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/good" python
    [[ "$status" -eq 0 ]]
    assert_json_field "$output" "status" "PASS"
    assert_json_field "$output" "language" "python"
    assert_json_field "$output" "parser" "ast"
}

@test "python: counts correct number of good steps" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/good" python
    [[ "$status" -eq 0 ]]
    assert_json_field "$output" "total_steps" "4"
    assert_json_field "$output" "quality_pass" "4"
    assert_json_field "$output" "quality_fail" "0"
}

@test "python: empty details array for passing steps" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/good" python
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"details": []'
}

# =============================================================================
# Python AST analysis - BLOCKED cases
# =============================================================================

@test "python: BLOCKED for bad step definitions" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/bad" python
    [[ "$status" -ne 0 ]]
    assert_json_field "$output" "status" "BLOCKED"
}

@test "python: detects EMPTY_BODY in given step" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/bad" python
    assert_contains "$output" '"issue": "EMPTY_BODY"'
    assert_contains "$output" '"step": "a user exists"'
}

@test "python: detects EMPTY_BODY in when step" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/bad" python
    assert_contains "$output" '"step": "the user performs an action"'
}

@test "python: detects TAUTOLOGY (assert True)" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/bad" python
    assert_contains "$output" '"issue": "TAUTOLOGY"'
    assert_contains "$output" '"step": "the result is correct"'
}

@test "python: detects TAUTOLOGY (assert 1)" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/bad" python
    assert_contains "$output" '"step": "everything works"'
}

@test "python: detects NO_ASSERTION in then step" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/bad" python
    assert_contains "$output" '"issue": "NO_ASSERTION"'
    assert_contains "$output" '"step": "the data is saved"'
}

@test "python: counts correct number of bad steps" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/bad" python
    assert_json_field "$output" "total_steps" "5"
    assert_json_field "$output" "quality_fail" "5"
    assert_json_field "$output" "quality_pass" "0"
}

@test "python: includes file and line in details" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/bad" python
    assert_contains "$output" '"file":'
    assert_contains "$output" '"line":'
}

# =============================================================================
# Python AST - inline fixture tests
# =============================================================================

@test "python: detects pass-only body" {
    mkdir -p "$TEST_DIR/steps"
    cat > "$TEST_DIR/steps/test_steps.py" <<'EOF'
from pytest_bdd import given

@given("something")
def step_impl():
    pass
EOF
    run "$VERIFY_SCRIPT" --json "$TEST_DIR/steps" python
    [[ "$status" -ne 0 ]]
    assert_contains "$output" '"issue": "EMPTY_BODY"'
}

@test "python: detects docstring-only body as empty" {
    mkdir -p "$TEST_DIR/steps"
    cat > "$TEST_DIR/steps/test_steps.py" <<'EOF'
from pytest_bdd import when

@when("something happens")
def step_impl():
    """This step is not implemented."""
EOF
    run "$VERIFY_SCRIPT" --json "$TEST_DIR/steps" python
    [[ "$status" -ne 0 ]]
    assert_contains "$output" '"issue": "EMPTY_BODY"'
}

@test "python: passes function with real assertion" {
    mkdir -p "$TEST_DIR/steps"
    cat > "$TEST_DIR/steps/test_steps.py" <<'EOF'
from pytest_bdd import then

@then("the value is 42")
def step_impl(context):
    assert context.value == 42
EOF
    run "$VERIFY_SCRIPT" --json "$TEST_DIR/steps" python
    [[ "$status" -eq 0 ]]
    assert_json_field "$output" "status" "PASS"
    assert_json_field "$output" "quality_fail" "0"
}

@test "python: PASS for empty directory (no steps)" {
    mkdir -p "$TEST_DIR/empty_steps"
    run "$VERIFY_SCRIPT" --json "$TEST_DIR/empty_steps" python
    [[ "$status" -eq 0 ]]
    assert_json_field "$output" "status" "PASS"
    assert_json_field "$output" "total_steps" "0"
}

# =============================================================================
# JavaScript analysis - PASS cases
# =============================================================================

@test "javascript: PASS for good step definitions" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/javascript/good" javascript
    [[ "$status" -eq 0 ]]
    assert_json_field "$output" "status" "PASS"
    assert_json_field "$output" "language" "javascript"
    assert_json_field "$output" "parser" "node"
}

@test "javascript: counts correct number of good steps" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/javascript/good" javascript
    [[ "$status" -eq 0 ]]
    assert_json_field "$output" "total_steps" "4"
    assert_json_field "$output" "quality_pass" "4"
}

# =============================================================================
# JavaScript analysis - BLOCKED cases
# =============================================================================

@test "javascript: BLOCKED for bad step definitions" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/javascript/bad" javascript
    [[ "$status" -ne 0 ]]
    assert_json_field "$output" "status" "BLOCKED"
}

@test "javascript: detects EMPTY_BODY" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/javascript/bad" javascript
    assert_contains "$output" '"issue":"EMPTY_BODY"'
}

@test "javascript: detects TAUTOLOGY" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/javascript/bad" javascript
    assert_contains "$output" '"issue":"TAUTOLOGY"'
}

@test "javascript: detects NO_ASSERTION in Then" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/javascript/bad" javascript
    assert_contains "$output" '"issue":"NO_ASSERTION"'
}

# =============================================================================
# Language aliases
# =============================================================================

@test "accepts 'py' as alias for python" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/good" py
    [[ "$status" -eq 0 ]]
    assert_json_field "$output" "language" "python"
}

@test "accepts 'js' as alias for javascript" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/javascript/good" js
    [[ "$status" -eq 0 ]]
    assert_json_field "$output" "language" "javascript"
}

@test "accepts 'ts' as alias for typescript" {
    mkdir -p "$TEST_DIR/ts_steps"
    run "$VERIFY_SCRIPT" --json "$TEST_DIR/ts_steps" ts
    [[ "$status" -eq 0 ]]
    assert_json_field "$output" "language" "typescript"
}

@test "language name is case-insensitive" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/good" PYTHON
    [[ "$status" -eq 0 ]]
    assert_json_field "$output" "language" "python"
}

# =============================================================================
# DEGRADED_ANALYSIS mode (regex fallback)
# =============================================================================

@test "java: uses regex fallback with DEGRADED_ANALYSIS note" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/java" java
    [[ "$status" -eq 0 ]]
    assert_json_field "$output" "parser" "regex"
    assert_contains "$output" 'DEGRADED_ANALYSIS'
    assert_contains "$output" '"parser_note"'
}

@test "java: detects step definitions via regex" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/java" java
    [[ "$status" -eq 0 ]]
    assert_json_field "$output" "total_steps" "3"
}

@test "java: parser_note mentions language name" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/java" java
    assert_contains "$output" 'java'
    assert_contains "$output" 'regex heuristics'
}

@test "go: uses regex fallback" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/go" go
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"parser"'
    assert_json_field "$output" "total_steps" "3"
}

@test "unknown language: falls back to regex with DEGRADED_ANALYSIS" {
    mkdir -p "$TEST_DIR/unknown_steps"
    touch "$TEST_DIR/unknown_steps/steps.rb"
    run "$VERIFY_SCRIPT" --json "$TEST_DIR/unknown_steps" ruby
    [[ "$status" -eq 0 ]]
    assert_contains "$output" 'DEGRADED_ANALYSIS'
}

# =============================================================================
# JSON output schema validation
# =============================================================================

@test "json output has required fields for PASS" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/good" python
    [[ "$status" -eq 0 ]]
    # Check all required fields exist
    assert_contains "$output" '"status"'
    assert_contains "$output" '"language"'
    assert_contains "$output" '"parser"'
    assert_contains "$output" '"total_steps"'
    assert_contains "$output" '"quality_pass"'
    assert_contains "$output" '"quality_fail"'
    assert_contains "$output" '"details"'
}

@test "json output has required fields for BLOCKED" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/bad" python
    # Check all required fields exist
    assert_contains "$output" '"status"'
    assert_contains "$output" '"language"'
    assert_contains "$output" '"parser"'
    assert_contains "$output" '"total_steps"'
    assert_contains "$output" '"quality_pass"'
    assert_contains "$output" '"quality_fail"'
    assert_contains "$output" '"details"'
}

@test "json output has required fields in detail items" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/bad" python
    # Detail items must have step, file, line, issue, severity
    assert_contains "$output" '"step"'
    assert_contains "$output" '"file"'
    assert_contains "$output" '"line"'
    assert_contains "$output" '"issue"'
    assert_contains "$output" '"severity"'
}

@test "json output is valid JSON" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/good" python
    [[ "$status" -eq 0 ]]
    # Validate with python json module
    echo "$output" | python3 -c "import json, sys; json.loads(sys.stdin.read())"
}

@test "json output for BLOCKED is valid JSON" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/bad" python
    echo "$output" | python3 -c "import json, sys; json.loads(sys.stdin.read())"
}

@test "json output for DEGRADED is valid JSON" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/java" java
    [[ "$status" -eq 0 ]]
    echo "$output" | python3 -c "import json, sys; json.loads(sys.stdin.read())"
}

# =============================================================================
# Exit code behavior
# =============================================================================

@test "exit code 0 for PASS" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/good" python
    [[ "$status" -eq 0 ]]
}

@test "exit code non-zero for BLOCKED" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/python/bad" python
    [[ "$status" -ne 0 ]]
}

@test "exit code 0 for DEGRADED_ANALYSIS (PASS with regex)" {
    run "$VERIFY_SCRIPT" --json "$FIXTURES_DIR/step-defs/java" java
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# Human-readable output mode
# =============================================================================

@test "text mode: shows step quality analysis header" {
    run "$VERIFY_SCRIPT" "$FIXTURES_DIR/step-defs/python/good" python
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Step Quality Analysis"
}

@test "text mode: shows language and parser" {
    run "$VERIFY_SCRIPT" "$FIXTURES_DIR/step-defs/python/good" python
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Language: python"
    assert_contains "$output" "Parser:   ast"
}

@test "text mode: shows issues for failures" {
    run "$VERIFY_SCRIPT" "$FIXTURES_DIR/step-defs/python/bad" python
    assert_contains "$output" "Issues:"
    assert_contains "$output" "EMPTY_BODY"
}
