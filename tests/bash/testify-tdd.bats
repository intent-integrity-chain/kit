#!/usr/bin/env bats
# Tests for testify-tdd.sh functions

load 'test_helper'

TESTIFY_SCRIPT="$SCRIPTS_DIR/testify-tdd.sh"

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# TDD Assessment tests
# =============================================================================

@test "assess-tdd: returns mandatory for MUST TDD" {
    result=$("$TESTIFY_SCRIPT" assess-tdd "$FIXTURES_DIR/constitution.md")
    assert_contains "$result" '"determination": "mandatory"'
    assert_contains "$result" '"confidence": "high"'
}

@test "assess-tdd: returns optional for no TDD indicators" {
    result=$("$TESTIFY_SCRIPT" assess-tdd "$FIXTURES_DIR/constitution-no-tdd.md")
    assert_contains "$result" '"determination": "optional"'
}

@test "assess-tdd: returns forbidden for TDD prohibition" {
    result=$("$TESTIFY_SCRIPT" assess-tdd "$FIXTURES_DIR/constitution-forbidden-tdd.md")
    assert_contains "$result" '"determination": "forbidden"'
}

@test "assess-tdd: returns error for missing file" {
    # Script returns non-zero exit and JSON with error
    run "$TESTIFY_SCRIPT" assess-tdd "/nonexistent/constitution.md"
    assert_contains "$output" '"error"'
}

@test "get-tdd-determination: returns just the determination" {
    result=$("$TESTIFY_SCRIPT" get-tdd-determination "$FIXTURES_DIR/constitution.md")
    [[ "$result" == "mandatory" ]]
}

@test "get-tdd-determination: returns unknown for missing file" {
    result=$("$TESTIFY_SCRIPT" get-tdd-determination "/nonexistent/constitution.md")
    [[ "$result" == "unknown" ]]
}

# =============================================================================
# Scenario counting tests
# =============================================================================

@test "count-scenarios: counts Given/When patterns" {
    result=$("$TESTIFY_SCRIPT" count-scenarios "$FIXTURES_DIR/spec.md")
    # The fixture has 3 acceptance scenarios
    [[ "$result" -ge 3 ]]
}

@test "count-scenarios: returns 0 for missing file" {
    result=$("$TESTIFY_SCRIPT" count-scenarios "/nonexistent/spec.md")
    [[ "$result" -eq 0 ]]
}

@test "has-scenarios: returns true for spec with scenarios" {
    result=$("$TESTIFY_SCRIPT" has-scenarios "$FIXTURES_DIR/spec.md")
    [[ "$result" == "true" ]]
}

@test "has-scenarios: returns false for spec without scenarios" {
    result=$("$TESTIFY_SCRIPT" has-scenarios "$FIXTURES_DIR/spec-incomplete.md")
    [[ "$result" == "false" ]]
}

# =============================================================================
# Assertion extraction tests
# =============================================================================

@test "extract-assertions: extracts Given/When/Then lines" {
    result=$("$TESTIFY_SCRIPT" extract-assertions "$FIXTURES_DIR/test-specs.md")
    assert_contains "$result" "**Given**:"
    assert_contains "$result" "**When**:"
    assert_contains "$result" "**Then**:"
}

@test "extract-assertions: returns empty for missing file" {
    result=$("$TESTIFY_SCRIPT" extract-assertions "/nonexistent/test-specs.md")
    [[ -z "$result" ]]
}

# =============================================================================
# Hash computation tests
# =============================================================================

@test "compute-hash: returns consistent hash" {
    hash1=$("$TESTIFY_SCRIPT" compute-hash "$FIXTURES_DIR/test-specs.md")
    hash2=$("$TESTIFY_SCRIPT" compute-hash "$FIXTURES_DIR/test-specs.md")
    [[ "$hash1" == "$hash2" ]]
}

@test "compute-hash: returns NO_ASSERTIONS for file without assertions" {
    echo "# Empty test specs" > "$TEST_DIR/empty-test-specs.md"
    result=$("$TESTIFY_SCRIPT" compute-hash "$TEST_DIR/empty-test-specs.md")
    [[ "$result" == "NO_ASSERTIONS" ]]
}

@test "compute-hash: returns 64-char hex string" {
    result=$("$TESTIFY_SCRIPT" compute-hash "$FIXTURES_DIR/test-specs.md")
    # SHA256 produces 64 hex characters
    [[ ${#result} -eq 64 ]]
}

# =============================================================================
# Hash storage and verification tests
# =============================================================================

@test "store-hash: creates context file and stores hash" {
    # Place test-specs.md in proper structure so derive_context_path resolves inside TEST_DIR
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    result=$("$TESTIFY_SCRIPT" store-hash "$test_specs")

    local context_file="$TEST_DIR/specs/001-test-feature/context.json"
    [[ -f "$context_file" ]]
    assert_contains "$(cat "$context_file")" '"assertion_hash"'
    assert_contains "$(cat "$context_file")" '"generated_at"'
}

@test "verify-hash: returns valid for matching hash" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    # Store hash first
    "$TESTIFY_SCRIPT" store-hash "$test_specs"

    # Verify it
    result=$("$TESTIFY_SCRIPT" verify-hash "$test_specs")
    [[ "$result" == "valid" ]]
}

@test "verify-hash: returns missing for no context file" {
    # Use a path where no context.json will exist
    mkdir -p "$TEST_DIR/specs/999-no-context/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/999-no-context/tests/test-specs.md"
    result=$("$TESTIFY_SCRIPT" verify-hash "$TEST_DIR/specs/999-no-context/tests/test-specs.md")
    [[ "$result" == "missing" ]]
}

@test "verify-hash: returns invalid for modified assertions" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    # Store hash
    "$TESTIFY_SCRIPT" store-hash "$test_specs"

    # Modify an assertion
    echo "**Given**: modified assertion" >> "$test_specs"

    # Verify should return invalid
    result=$("$TESTIFY_SCRIPT" verify-hash "$test_specs")
    [[ "$result" == "invalid" ]]
}

# =============================================================================
# Rehash alias tests
# =============================================================================

@test "rehash: works as alias for store-hash" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    result=$("$TESTIFY_SCRIPT" rehash "$test_specs")

    local context_file="$TEST_DIR/specs/001-test-feature/context.json"
    [[ -f "$context_file" ]]
    assert_contains "$(cat "$context_file")" '"assertion_hash"'
}

@test "rehash: produces hash that passes verify-hash" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    "$TESTIFY_SCRIPT" rehash "$test_specs"

    result=$("$TESTIFY_SCRIPT" verify-hash "$test_specs")
    [[ "$result" == "valid" ]]
}

@test "rehash: returns same hash as compute-hash" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    rehash_result=$("$TESTIFY_SCRIPT" rehash "$test_specs")
    compute_result=$("$TESTIFY_SCRIPT" compute-hash "$test_specs")
    [[ "$rehash_result" == "$compute_result" ]]
}

@test "rehash: errors without file argument" {
    run "$TESTIFY_SCRIPT" rehash
    [[ "$status" -ne 0 ]]
}

# =============================================================================
# Comprehensive check tests
# =============================================================================

@test "comprehensive-check: returns PASS for valid setup" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    "$TESTIFY_SCRIPT" store-hash "$test_specs"

    result=$("$TESTIFY_SCRIPT" comprehensive-check "$test_specs" "$FIXTURES_DIR/constitution.md")
    assert_contains "$result" '"overall_status": "PASS"'
}

@test "comprehensive-check: returns BLOCKED for tampered assertions" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    "$TESTIFY_SCRIPT" store-hash "$test_specs"

    # Tamper with assertions
    echo "**Then**: tampered assertion" >> "$test_specs"

    result=$("$TESTIFY_SCRIPT" comprehensive-check "$test_specs" "$FIXTURES_DIR/constitution.md")
    assert_contains "$result" '"overall_status": "BLOCKED"'
}

@test "comprehensive-check: includes TDD determination" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests"
    cp "$FIXTURES_DIR/test-specs.md" "$TEST_DIR/specs/001-test-feature/tests/test-specs.md"
    local test_specs="$TEST_DIR/specs/001-test-feature/tests/test-specs.md"

    "$TESTIFY_SCRIPT" store-hash "$test_specs"

    result=$("$TESTIFY_SCRIPT" comprehensive-check "$test_specs" "$FIXTURES_DIR/constitution.md")
    assert_contains "$result" '"tdd_determination": "mandatory"'
}

# =============================================================================
# .feature file support — helper
# =============================================================================

# Create standard .feature fixture files in a given directory
create_feature_fixtures() {
    local dir="$1"
    mkdir -p "$dir"

    cat > "$dir/login.feature" <<'FEATURE'
Feature: Login
  @FR-001 @acceptance
  Scenario: Valid login
    Given a registered user
    When they enter valid credentials
    Then they are logged in
    And they see the dashboard
FEATURE

    cat > "$dir/logout.feature" <<'FEATURE'
Feature: Logout
  @FR-002 @acceptance
  Scenario: User logout
    Given a logged in user
    When they click logout
    But they have unsaved changes
    Then they see a confirmation dialog
FEATURE
}

# =============================================================================
# .feature file — extract-assertions tests
# =============================================================================

@test "extract-assertions: extracts step lines from .feature directory" {
    local features_dir="$TEST_DIR/features_extract"
    create_feature_fixtures "$features_dir"

    result=$("$TESTIFY_SCRIPT" extract-assertions "$features_dir")

    # login.feature comes before logout.feature alphabetically
    assert_contains "$result" "Given a registered user"
    assert_contains "$result" "When they enter valid credentials"
    assert_contains "$result" "Then they are logged in"
    assert_contains "$result" "And they see the dashboard"
    assert_contains "$result" "Given a logged in user"
    assert_contains "$result" "When they click logout"
    assert_contains "$result" "But they have unsaved changes"
    assert_contains "$result" "Then they see a confirmation dialog"
}

@test "extract-assertions: handles single .feature file" {
    local features_dir="$TEST_DIR/features_single"
    create_feature_fixtures "$features_dir"

    result=$("$TESTIFY_SCRIPT" extract-assertions "$features_dir/login.feature")

    assert_contains "$result" "Given a registered user"
    assert_contains "$result" "When they enter valid credentials"
    assert_contains "$result" "Then they are logged in"
    assert_contains "$result" "And they see the dashboard"
    # Should NOT contain logout steps
    assert_not_contains "$result" "Given a logged in user"
}

@test "extract-assertions: returns empty for directory with no .feature files" {
    local empty_dir="$TEST_DIR/features_empty"
    mkdir -p "$empty_dir"

    run "$TESTIFY_SCRIPT" extract-assertions "$empty_dir"
    [[ -z "$output" ]]
}

@test "extract-assertions: normalizes whitespace in .feature files" {
    local features_dir="$TEST_DIR/features_ws"
    mkdir -p "$features_dir"

    # Create a .feature file with extra leading spaces and internal whitespace
    cat > "$features_dir/whitespace.feature" <<'FEATURE'
Feature: Whitespace test
  Scenario: Extra spaces
        Given   a   user   with   spaces
        When    they   do   something
        Then    it   works
FEATURE

    result=$("$TESTIFY_SCRIPT" extract-assertions "$features_dir")

    # Leading whitespace should be stripped, internal whitespace collapsed to single space
    assert_contains "$result" "Given a user with spaces"
    assert_contains "$result" "When they do something"
    assert_contains "$result" "Then it works"
}

# =============================================================================
# .feature file — compute-hash tests
# =============================================================================

@test "compute-hash: returns consistent hash for .feature directory" {
    local features_dir="$TEST_DIR/features_hash"
    create_feature_fixtures "$features_dir"

    hash1=$("$TESTIFY_SCRIPT" compute-hash "$features_dir")
    hash2=$("$TESTIFY_SCRIPT" compute-hash "$features_dir")
    [[ "$hash1" == "$hash2" ]]
}

@test "compute-hash: returns NO_ASSERTIONS for empty .feature directory" {
    local features_dir="$TEST_DIR/features_no_steps"
    mkdir -p "$features_dir"

    # Create a .feature file with no step lines
    cat > "$features_dir/empty.feature" <<'FEATURE'
Feature: No steps here
  # just a comment
  Scenario: placeholder
FEATURE

    result=$("$TESTIFY_SCRIPT" compute-hash "$features_dir")
    [[ "$result" == "NO_ASSERTIONS" ]]
}

@test "compute-hash: returns 64-char hex for .feature directory" {
    local features_dir="$TEST_DIR/features_hex"
    create_feature_fixtures "$features_dir"

    result=$("$TESTIFY_SCRIPT" compute-hash "$features_dir")
    # SHA256 produces 64 hex characters
    [[ ${#result} -eq 64 ]]
}

# =============================================================================
# .feature file — store-hash tests
# =============================================================================

@test "store-hash: stores features_dir and file_count for directory input" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests/features"
    create_feature_fixtures "$TEST_DIR/specs/001-test-feature/tests/features"
    local features_dir="$TEST_DIR/specs/001-test-feature/tests/features"

    "$TESTIFY_SCRIPT" store-hash "$features_dir"

    local context_file="$TEST_DIR/specs/001-test-feature/context.json"
    [[ -f "$context_file" ]]
    assert_contains "$(cat "$context_file")" '"features_dir"'
    assert_contains "$(cat "$context_file")" '"file_count"'
    # Should NOT contain legacy test_specs_file
    assert_not_contains "$(cat "$context_file")" '"test_specs_file"'
}

# =============================================================================
# .feature file — verify-hash tests
# =============================================================================

@test "verify-hash: returns valid for matching hash with .feature directory" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests/features"
    create_feature_fixtures "$TEST_DIR/specs/001-test-feature/tests/features"
    local features_dir="$TEST_DIR/specs/001-test-feature/tests/features"

    # Store hash first
    "$TESTIFY_SCRIPT" store-hash "$features_dir"

    # Verify it
    result=$("$TESTIFY_SCRIPT" verify-hash "$features_dir")
    [[ "$result" == "valid" ]]
}

@test "verify-hash: returns invalid for modified .feature file" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests/features"
    create_feature_fixtures "$TEST_DIR/specs/001-test-feature/tests/features"
    local features_dir="$TEST_DIR/specs/001-test-feature/tests/features"

    # Store hash
    "$TESTIFY_SCRIPT" store-hash "$features_dir"

    # Modify a .feature file step line
    echo "    Given a completely new step line" >> "$features_dir/login.feature"

    # Verify should return invalid
    result=$("$TESTIFY_SCRIPT" verify-hash "$features_dir")
    [[ "$result" == "invalid" ]]
}

# =============================================================================
# .feature file — comprehensive-check tests
# =============================================================================

@test "comprehensive-check: returns PASS for valid .feature directory" {
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests/features"
    create_feature_fixtures "$TEST_DIR/specs/001-test-feature/tests/features"
    local features_dir="$TEST_DIR/specs/001-test-feature/tests/features"

    "$TESTIFY_SCRIPT" store-hash "$features_dir"

    result=$("$TESTIFY_SCRIPT" comprehensive-check "$features_dir" "$FIXTURES_DIR/constitution.md")
    assert_contains "$result" '"overall_status": "PASS"'
}

# =============================================================================
# .feature file — derive-context-path tests
# =============================================================================

@test "derive-context-path: correct for features directory" {
    # For a features directory at tests/features/, derive_context_path should go 2 levels up
    # tests/features/ -> tests/ -> specs/NNN-feature/ -> context.json
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests/features"
    local features_dir="$TEST_DIR/specs/001-test-feature/tests/features"

    # We can test derive-context-path by storing a hash and checking where context.json lands
    create_feature_fixtures "$features_dir"
    "$TESTIFY_SCRIPT" store-hash "$features_dir"

    # context.json should be at specs/001-test-feature/context.json (2 levels up from tests/features/)
    local expected_context="$TEST_DIR/specs/001-test-feature/context.json"
    [[ -f "$expected_context" ]]
}
