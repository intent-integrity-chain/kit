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
# .feature file — valid hash tests
# =============================================================================

@test "hook: exit 0 when .feature files staged with valid hash" {
    # Create feature with .feature files
    mkdir -p "$TEST_DIR/specs/001-feature/tests/features"
    cat > "$TEST_DIR/specs/001-feature/tests/features/login.feature" << 'EOF'
Feature: Test
  Scenario: Test scenario
    Given a test precondition
    When a test action occurs
    Then a test result is observed
EOF

    # Store hash via testify-tdd.sh store-hash on the features directory
    "$TESTIFY_SCRIPT" store-hash "$TEST_DIR/specs/001-feature/tests/features" > /dev/null

    # Stage and commit the initial state
    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit -m "add feature files with hash" >/dev/null 2>&1

    # Re-stage unchanged .feature files (no-op edit, re-add)
    git -C "$TEST_DIR" add specs/001-feature/tests/features/login.feature

    # Hook should pass
    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
}

# =============================================================================
# .feature file — tampered assertions tests
# =============================================================================

@test "hook: exit 1 when .feature file assertions tampered" {
    # Create .feature files
    mkdir -p "$TEST_DIR/specs/001-feature/tests/features"
    cat > "$TEST_DIR/specs/001-feature/tests/features/login.feature" << 'EOF'
Feature: Test
  Scenario: Test scenario
    Given a test precondition
    When a test action occurs
    Then a test result is observed
EOF

    # Store hash
    "$TESTIFY_SCRIPT" store-hash "$TEST_DIR/specs/001-feature/tests/features" > /dev/null

    # Commit original state
    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit -m "add feature files" >/dev/null 2>&1

    # Modify a step line in the .feature file (tamper with assertions)
    cat > "$TEST_DIR/specs/001-feature/tests/features/login.feature" << 'EOF'
Feature: Test
  Scenario: Test scenario
    Given a test precondition
    When a test action occurs
    Then a DIFFERENT result is observed
EOF

    # Stage modified .feature file
    git -C "$TEST_DIR" add specs/001-feature/tests/features/login.feature

    # Hook should BLOCK
    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 1 ]
    assert_contains "$output" "ASSERTION INTEGRITY CHECK FAILED"
}

# =============================================================================
# .feature file — missing hash tests
# =============================================================================

@test "hook: exit 0 when .feature files have no stored hash" {
    # Create .feature files without storing hash
    mkdir -p "$TEST_DIR/specs/001-feature/tests/features"
    cat > "$TEST_DIR/specs/001-feature/tests/features/login.feature" << 'EOF'
Feature: Test
  Scenario: Test scenario
    Given a test precondition
    When a test action occurs
    Then a test result is observed
EOF

    # Stage them (no hash stored, no context.json)
    git -C "$TEST_DIR" add specs/001-feature/tests/features/login.feature

    # Hook should pass (missing hash doesn't block)
    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
}

# =============================================================================
# .feature file — whitespace-only changes tests
# =============================================================================

@test "hook: exit 0 when .feature whitespace-only changes" {
    # Create .feature files
    mkdir -p "$TEST_DIR/specs/001-feature/tests/features"
    cat > "$TEST_DIR/specs/001-feature/tests/features/login.feature" << 'EOF'
Feature: Test
  Scenario: Test scenario
    Given a test precondition
    When a test action occurs
    Then a test result is observed
EOF

    # Store hash
    "$TESTIFY_SCRIPT" store-hash "$TEST_DIR/specs/001-feature/tests/features" > /dev/null

    # Commit original state
    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit -m "add feature files" >/dev/null 2>&1

    # Change only indentation/comments (whitespace-only, step content unchanged)
    cat > "$TEST_DIR/specs/001-feature/tests/features/login.feature" << 'EOF'
Feature: Test
  # Added a comment here
  Scenario: Test scenario
      Given a test precondition
      When a test action occurs
      Then a test result is observed
EOF

    # Stage modified .feature file
    git -C "$TEST_DIR" add specs/001-feature/tests/features/login.feature

    # Hook should pass — step content unchanged (whitespace normalized)
    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
}

# =============================================================================
# Scripts not found tests
# =============================================================================

# =============================================================================
# BDD runner enforcement tests
# =============================================================================

@test "hook: warns (not blocks) when .feature files exist but no step_definitions" {
    # Create feature with .feature files
    mkdir -p "$TEST_DIR/specs/001-feature/tests/features"
    cat > "$TEST_DIR/specs/001-feature/tests/features/login.feature" << 'EOF'
Feature: Login
  Scenario: Valid login
    Given a registered user
    When they enter valid credentials
    Then they see the dashboard
EOF

    # Create a plan.md so framework detection works
    mkdir -p "$TEST_DIR/specs/001-feature"
    echo "**Language/Version**: Python 3.12 with pytest-bdd" > "$TEST_DIR/specs/001-feature/plan.md"

    # Commit the feature files so they exist in the repo
    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit -m "add feature files" >/dev/null 2>&1

    # Now stage a code file — should warn but NOT block
    echo "def login(): pass" > "$TEST_DIR/app.py"
    git -C "$TEST_DIR" add app.py

    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
    assert_contains "$output" "missing step definitions"
}

@test "hook: warns (not blocks) when step_definitions exist but dependency missing" {
    # Create feature with .feature files AND step definitions
    mkdir -p "$TEST_DIR/specs/001-feature/tests/features"
    mkdir -p "$TEST_DIR/specs/001-feature/tests/step_definitions"
    cat > "$TEST_DIR/specs/001-feature/tests/features/login.feature" << 'EOF'
Feature: Login
  Scenario: Valid login
    Given a registered user
    When they enter valid credentials
    Then they see the dashboard
EOF
    echo "from pytest_bdd import given" > "$TEST_DIR/specs/001-feature/tests/step_definitions/test_login.py"

    # Plan.md detects pytest-bdd
    echo "**Language/Version**: Python 3.12 with pytest-bdd" > "$TEST_DIR/specs/001-feature/plan.md"

    # NO requirements.txt with pytest-bdd

    # Commit everything so .feature files exist in repo (bypass hook for setup)
    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit --no-verify -m "add feature setup" >/dev/null 2>&1

    # Stage a code file
    echo "def login(): pass" > "$TEST_DIR/app.py"
    git -C "$TEST_DIR" add app.py

    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
    assert_contains "$output" "pytest-bdd"
    assert_contains "$output" "not found"
}

@test "hook: passes code commit when BDD setup is complete" {
    # Create full BDD setup: features + step_definitions + dependency
    mkdir -p "$TEST_DIR/specs/001-feature/tests/features"
    mkdir -p "$TEST_DIR/specs/001-feature/tests/step_definitions"
    cat > "$TEST_DIR/specs/001-feature/tests/features/login.feature" << 'EOF'
Feature: Login
  Scenario: Valid login
    Given a registered user
    When they enter valid credentials
    Then they see the dashboard
EOF
    echo "from pytest_bdd import given" > "$TEST_DIR/specs/001-feature/tests/step_definitions/test_login.py"
    echo "**Language/Version**: Python 3.12 with pytest-bdd" > "$TEST_DIR/specs/001-feature/plan.md"
    echo "pytest-bdd>=7.0" > "$TEST_DIR/requirements.txt"

    # Commit everything
    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit -m "full bdd setup" >/dev/null 2>&1

    # Stage a code file
    echo "def login(): pass" > "$TEST_DIR/app.py"
    git -C "$TEST_DIR" add app.py

    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    # Should pass (gate 3 may degrade if pytest not installed, but won't block)
    [ "$status" -eq 0 ]
}

@test "hook: no BDD enforcement when no .feature files exist" {
    # No .feature files at all — code commit should pass through fast
    echo "def hello(): pass" > "$TEST_DIR/app.py"
    git -C "$TEST_DIR" add app.py

    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
}

@test "hook: no BDD enforcement when only .feature files staged (testify phase)" {
    # Staging .feature files only — BDD enforcement should NOT trigger
    mkdir -p "$TEST_DIR/specs/001-feature/tests/features"
    cat > "$TEST_DIR/specs/001-feature/tests/features/login.feature" << 'EOF'
Feature: Login
  Scenario: Valid login
    Given a registered user
    When they enter valid credentials
    Then they see the dashboard
EOF

    git -C "$TEST_DIR" add specs/001-feature/tests/features/login.feature

    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    # .feature files staged but no code files => BDD enforcement skipped
    # Assertion integrity check runs but no stored hash => passes (missing = ok)
    [ "$status" -eq 0 ]
}

@test "hook: BDD enforcement skips features without .feature files" {
    # Feature 001 has .feature files, feature 002 does not
    mkdir -p "$TEST_DIR/specs/001-feature/tests/features"
    mkdir -p "$TEST_DIR/specs/001-feature/tests/step_definitions"
    cat > "$TEST_DIR/specs/001-feature/tests/features/login.feature" << 'EOF'
Feature: Login
  Scenario: Valid login
    Given a registered user
    When they enter valid credentials
    Then they see the dashboard
EOF
    echo "from pytest_bdd import given" > "$TEST_DIR/specs/001-feature/tests/step_definitions/test_login.py"
    echo "**Language/Version**: Python 3.12 with pytest-bdd" > "$TEST_DIR/specs/001-feature/plan.md"
    echo "pytest-bdd>=7.0" > "$TEST_DIR/requirements.txt"

    # Feature 002 has no .feature files — should be unaffected
    mkdir -p "$TEST_DIR/specs/002-other-feature"
    echo "# Spec" > "$TEST_DIR/specs/002-other-feature/spec.md"

    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit -m "setup" >/dev/null 2>&1

    echo "def app(): pass" > "$TEST_DIR/app.py"
    git -C "$TEST_DIR" add app.py

    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
}

# =============================================================================
# TDD mandatory warning tests
# =============================================================================

@test "hook: warns when TDD mandatory and no .feature files exist" {
    # Create constitution with mandatory TDD
    cat > "$TEST_DIR/CONSTITUTION.md" << 'EOF'
# Constitution
TDD MUST be used for all features.
EOF
    # Create a feature dir with NO .feature files
    mkdir -p "$TEST_DIR/specs/001-feature"
    echo "# Spec" > "$TEST_DIR/specs/001-feature/spec.md"

    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit --no-verify -m "setup" >/dev/null 2>&1

    # Stage a code file
    echo "def app(): pass" > "$TEST_DIR/app.py"
    git -C "$TEST_DIR" add app.py

    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    # Should pass (warning only, not blocking) but emit TDD warning
    [ "$status" -eq 0 ]
    assert_contains "$output" "TDD is mandatory"
    assert_contains "$output" "/iikit-04-testify"
}

@test "hook: no TDD warning when .feature files exist" {
    # Create constitution with mandatory TDD
    cat > "$TEST_DIR/CONSTITUTION.md" << 'EOF'
# Constitution
TDD MUST be used for all features.
EOF
    # Create feature with .feature files + full BDD setup
    mkdir -p "$TEST_DIR/specs/001-feature/tests/features"
    mkdir -p "$TEST_DIR/specs/001-feature/tests/step_definitions"
    echo "Feature: Test" > "$TEST_DIR/specs/001-feature/tests/features/test.feature"
    echo "step" > "$TEST_DIR/specs/001-feature/tests/step_definitions/steps.py"
    echo "**Language/Version**: Python with pytest-bdd" > "$TEST_DIR/specs/001-feature/plan.md"
    echo "pytest-bdd" > "$TEST_DIR/requirements.txt"

    git -C "$TEST_DIR" add -A >/dev/null 2>&1
    git -C "$TEST_DIR" commit --no-verify -m "setup" >/dev/null 2>&1

    echo "def app(): pass" > "$TEST_DIR/app.py"
    git -C "$TEST_DIR" add app.py

    cd "$TEST_DIR"
    run bash .git/hooks/pre-commit
    [ "$status" -eq 0 ]
    assert_not_contains "$output" "TDD is mandatory"
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

# =============================================================================
# Bug regression tests (from e2e test findings)
# =============================================================================

@test "BUG-23: pre-commit allows commit when .feature files exist but step_definitions missing" {
    # TDD mandatory constitution
    create_complete_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests/features"
    echo "Feature: Test" > "$TEST_DIR/specs/001-test-feature/tests/features/auth.feature"
    # Store assertion hash so hash check passes
    cd "$TEST_DIR"
    bash "$TESTIFY_SCRIPT" store-hash "$TEST_DIR/specs/001-test-feature/tests/features" 2>/dev/null || true

    # Stage a code file (not a spec/test file)
    mkdir -p "$TEST_DIR/src"
    echo "console.log('hello');" > "$TEST_DIR/src/index.js"
    git -C "$TEST_DIR" add src/index.js

    # Pre-commit should NOT block just because step_definitions/ is missing
    # The agent hasn't had a chance to create them yet
    run bash .git/hooks/pre-commit
    [[ "$status" -eq 0 ]]
}

@test "BUG-24: pre-commit allows commit when BDD runner not in package.json" {
    create_complete_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/specs/001-test-feature/tests/features"
    echo "Feature: Test" > "$TEST_DIR/specs/001-test-feature/tests/features/auth.feature"
    cd "$TEST_DIR"
    bash "$TESTIFY_SCRIPT" store-hash "$TEST_DIR/specs/001-test-feature/tests/features" 2>/dev/null || true

    # Create package.json WITHOUT @cucumber/cucumber
    echo '{"name":"test","version":"1.0.0"}' > "$TEST_DIR/package.json"

    mkdir -p "$TEST_DIR/src"
    echo "module.exports = {};" > "$TEST_DIR/src/app.js"
    git -C "$TEST_DIR" add src/app.js package.json

    # Pre-commit should NOT block for missing dependency before npm install
    run bash .git/hooks/pre-commit
    [[ "$status" -eq 0 ]]
}
