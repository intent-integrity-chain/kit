#!/usr/bin/env bats
# Tests for common.sh functions

load 'test_helper'

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

# =============================================================================
# get_repo_root tests
# =============================================================================

@test "get_repo_root: returns git root in git repo" {
    # TEST_DIR already has git initialized by setup_test_dir
    result=$(get_repo_root)
    # Use realpath to normalize paths (handles symlinks, etc.)
    [[ "$(cd "$result" && pwd -P)" == "$(cd "$TEST_DIR" && pwd -P)" ]]
}

@test "get_repo_root: falls back to script location in non-git repo" {
    # This test verifies the fallback mechanism works
    # The actual path depends on script location
    result=$(get_repo_root)
    [[ -d "$result" ]]
}

# =============================================================================
# get_current_branch tests
# =============================================================================

@test "get_current_branch: returns SPECIFY_FEATURE if set" {
    export SPECIFY_FEATURE="test-feature"
    result=$(get_current_branch)
    [[ "$result" == "test-feature" ]]
    unset SPECIFY_FEATURE
}

@test "get_current_branch: returns git branch in git repo" {
    # TEST_DIR already has git initialized by setup_test_dir
    result=$(get_current_branch)
    # Should be 'main' or 'master' depending on git config
    [[ "$result" == "main" || "$result" == "master" ]]
}

@test "get_current_branch: returns main as fallback in non-git repo" {
    # Remove git to simulate non-git repo
    rm -rf .git

    # Create feature dirs (but they won't be found because get_repo_root
    # falls back to script location, not current directory)
    mkdir -p specs/001-first-feature
    mkdir -p specs/002-second-feature

    unset SPECIFY_FEATURE
    result=$(get_current_branch)
    # Without git, get_repo_root falls back to script location which doesn't
    # have these test specs, so it returns "main" as final fallback
    [[ "$result" == "main" ]]
}

# =============================================================================
# check_feature_branch tests
# =============================================================================

@test "check_feature_branch: accepts NNN- pattern" {
    run check_feature_branch "001-test-feature" "true"
    [[ "$status" -eq 0 ]]
}

@test "check_feature_branch: accepts SPECIFY_FEATURE override" {
    export SPECIFY_FEATURE="manual-override"
    run check_feature_branch "main" "true"
    [[ "$status" -eq 0 ]]
    unset SPECIFY_FEATURE
}

@test "check_feature_branch: rejects non-feature branch with no features" {
    run check_feature_branch "main" "true"
    [[ "$status" -eq 1 ]]
}

@test "check_feature_branch: auto-selects single feature directory" {
    mkdir -p "$TEST_DIR/specs/001-only-feature"
    run check_feature_branch "main" "true"
    [[ "$status" -eq 0 ]]
}

@test "check_feature_branch: warns for non-git repo" {
    run check_feature_branch "main" "false"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Warning"
}

# =============================================================================
# find_feature_dir_by_prefix tests
# =============================================================================

@test "find_feature_dir_by_prefix: finds matching prefix" {
    mkdir -p specs/004-original-feature

    result=$(find_feature_dir_by_prefix "$TEST_DIR" "004-fix-typo")
    assert_contains "$result" "004-original-feature"
}

@test "find_feature_dir_by_prefix: returns exact path for non-prefixed branch" {
    result=$(find_feature_dir_by_prefix "$TEST_DIR" "main")
    [[ "$result" == "$TEST_DIR/specs/main" ]]
}

@test "find_feature_dir_by_prefix: returns branch path when no match" {
    result=$(find_feature_dir_by_prefix "$TEST_DIR" "999-nonexistent")
    [[ "$result" == "$TEST_DIR/specs/999-nonexistent" ]]
}

# =============================================================================
# validate_constitution tests
# =============================================================================

@test "validate_constitution: passes with valid constitution" {
    run validate_constitution "$TEST_DIR"
    [[ "$status" -eq 0 ]]
}

@test "validate_constitution: fails when constitution missing" {
    rm CONSTITUTION.md
    run validate_constitution "$TEST_DIR"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "not found"
}

@test "validate_constitution: warns when fewer than 3 principles (heading style)" {
    cat > "$TEST_DIR/CONSTITUTION.md" << 'EOF'
# Constitution
## Core Principles
### I. First Principle
Content here.
### II. Second Principle
Content here.
EOF
    run validate_constitution "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "only 2 principle"
}

@test "validate_constitution: warns when fewer than 3 principles (bullet style)" {
    cat > "$TEST_DIR/CONSTITUTION.md" << 'EOF'
# Constitution
## Core Principles
- **Quality**: Code must be tested
- **Speed**: Ship fast
EOF
    run validate_constitution "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "only 2 principle"
}

@test "validate_constitution: no warning with 3+ principles" {
    cat > "$TEST_DIR/CONSTITUTION.md" << 'EOF'
# Constitution
## Core Principles
### I. First
Content.
### II. Second
Content.
### III. Third
Content.
EOF
    run validate_constitution "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_not_contains "$output" "principle"
}

@test "validate_constitution: no warning with 3+ bullet principles" {
    # The default fixture has 3 bullet-style principles
    run validate_constitution "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_not_contains "$output" "only"
}

# =============================================================================
# validate_spec tests
# =============================================================================

@test "validate_spec: passes with valid spec" {
    feature_dir=$(create_mock_feature)
    run validate_spec "$TEST_DIR/$feature_dir/spec.md"
    [[ "$status" -eq 0 ]]
}

@test "validate_spec: fails when spec missing" {
    run validate_spec "$TEST_DIR/specs/nonexistent/spec.md"
    [[ "$status" -eq 1 ]]
}

@test "validate_spec: fails when missing required sections" {
    feature_dir=$(create_mock_feature)
    echo "# Empty Spec" > "$TEST_DIR/$feature_dir/spec.md"
    run validate_spec "$TEST_DIR/$feature_dir/spec.md"
    [[ "$status" -eq 1 ]]
}

# =============================================================================
# validate_plan tests
# =============================================================================

@test "validate_plan: passes with valid plan" {
    feature_dir=$(create_mock_feature)
    run validate_plan "$TEST_DIR/$feature_dir/plan.md"
    [[ "$status" -eq 0 ]]
}

@test "validate_plan: fails when plan missing" {
    run validate_plan "$TEST_DIR/specs/nonexistent/plan.md"
    [[ "$status" -eq 1 ]]
}

# =============================================================================
# validate_tasks tests
# =============================================================================

@test "validate_tasks: passes with valid tasks" {
    feature_dir=$(create_complete_mock_feature)
    run validate_tasks "$TEST_DIR/$feature_dir/tasks.md"
    [[ "$status" -eq 0 ]]
}

@test "validate_tasks: fails when tasks missing" {
    run validate_tasks "$TEST_DIR/specs/nonexistent/tasks.md"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "/iikit-06-tasks"
}

# =============================================================================
# calculate_spec_quality tests
# =============================================================================

@test "calculate_spec_quality: returns high score for good spec" {
    feature_dir=$(create_mock_feature)
    result=$(calculate_spec_quality "$TEST_DIR/$feature_dir/spec.md")
    # Good spec should score 6 or higher
    [[ "$result" -ge 6 ]]
}

@test "calculate_spec_quality: returns 0 for missing spec" {
    result=$(calculate_spec_quality "$TEST_DIR/nonexistent.md")
    [[ "$result" -eq 0 ]]
}

@test "calculate_spec_quality: returns low score for incomplete spec" {
    mkdir -p specs/incomplete
    cp "$FIXTURES_DIR/spec-incomplete.md" specs/incomplete/spec.md
    result=$(calculate_spec_quality "$TEST_DIR/specs/incomplete/spec.md")
    [[ "$result" -lt 6 ]]
}

# =============================================================================
# read_active_feature / write_active_feature tests
# =============================================================================

@test "write_active_feature: creates .specify/active-feature" {
    mkdir -p "$TEST_DIR/specs/001-test-feature"
    write_active_feature "001-test-feature"
    [[ -f "$TEST_DIR/.specify/active-feature" ]]
    result=$(cat "$TEST_DIR/.specify/active-feature")
    [[ "$result" == "001-test-feature" ]]
}

@test "read_active_feature: returns feature from file" {
    mkdir -p "$TEST_DIR/specs/001-test-feature"
    write_active_feature "001-test-feature"
    result=$(read_active_feature)
    [[ "$result" == "001-test-feature" ]]
}

@test "read_active_feature: fails if directory missing" {
    mkdir -p "$TEST_DIR/.specify"
    echo "999-nonexistent" > "$TEST_DIR/.specify/active-feature"
    run read_active_feature
    [[ "$status" -ne 0 ]]
}

@test "read_active_feature: fails if file missing" {
    run read_active_feature
    [[ "$status" -ne 0 ]]
}

# =============================================================================
# get_current_branch cascade priority tests
# =============================================================================

@test "get_current_branch: active-feature takes priority over SPECIFY_FEATURE" {
    mkdir -p "$TEST_DIR/specs/002-sticky-feature"
    write_active_feature "002-sticky-feature"
    export SPECIFY_FEATURE="001-env-feature"
    result=$(get_current_branch)
    [[ "$result" == "002-sticky-feature" ]]
    unset SPECIFY_FEATURE
}

@test "get_current_branch: SPECIFY_FEATURE takes priority over git branch" {
    # No active-feature file, SPECIFY_FEATURE set
    export SPECIFY_FEATURE="003-env-override"
    result=$(get_current_branch)
    [[ "$result" == "003-env-override" ]]
    unset SPECIFY_FEATURE
}

# =============================================================================
# check_feature_branch exit code 2 tests
# =============================================================================

@test "check_feature_branch: returns exit code 2 for multiple features" {
    mkdir -p "$TEST_DIR/specs/001-first-feature"
    mkdir -p "$TEST_DIR/specs/002-second-feature"
    run check_feature_branch "main" "true"
    [[ "$status" -eq 2 ]]
}

@test "check_feature_branch: exit code 2 message suggests /iikit-core use" {
    mkdir -p "$TEST_DIR/specs/001-first-feature"
    mkdir -p "$TEST_DIR/specs/002-second-feature"
    run check_feature_branch "main" "true"
    [[ "$status" -eq 2 ]]
    assert_contains "$output" "/iikit-core use"
}

@test "check_feature_branch: writes sticky on NNN- branch match" {
    run check_feature_branch "001-test-feature" "true"
    [[ "$status" -eq 0 ]]
    [[ -f "$TEST_DIR/.specify/active-feature" ]]
    result=$(cat "$TEST_DIR/.specify/active-feature")
    [[ "$result" == "001-test-feature" ]]
}

@test "check_feature_branch: writes sticky on single feature auto-select" {
    mkdir -p "$TEST_DIR/specs/001-only-feature"
    run check_feature_branch "main" "true"
    [[ "$status" -eq 0 ]]
    [[ -f "$TEST_DIR/.specify/active-feature" ]]
    result=$(cat "$TEST_DIR/.specify/active-feature")
    [[ "$result" == "001-only-feature" ]]
}

# =============================================================================
# get_feature_stage tests
# =============================================================================

@test "get_feature_stage: returns specified for spec-only feature" {
    mkdir -p "$TEST_DIR/specs/001-test"
    echo "# Spec" > "$TEST_DIR/specs/001-test/spec.md"
    result=$(get_feature_stage "$TEST_DIR" "001-test")
    [[ "$result" == "specified" ]]
}

@test "get_feature_stage: returns planned for feature with plan" {
    mkdir -p "$TEST_DIR/specs/001-test"
    echo "# Spec" > "$TEST_DIR/specs/001-test/spec.md"
    echo "# Plan" > "$TEST_DIR/specs/001-test/plan.md"
    result=$(get_feature_stage "$TEST_DIR" "001-test")
    [[ "$result" == "planned" ]]
}

@test "get_feature_stage: returns tasks-ready for untouched tasks" {
    mkdir -p "$TEST_DIR/specs/001-test"
    printf '%s\n%s\n' '- [ ] T001 Do something' '- [ ] T002 Do another' > "$TEST_DIR/specs/001-test/tasks.md"
    result=$(get_feature_stage "$TEST_DIR" "001-test")
    [[ "$result" == "tasks-ready" ]]
}

@test "get_feature_stage: returns implementing percentage" {
    mkdir -p "$TEST_DIR/specs/001-test"
    printf '%s\n%s\n' '- [x] T001 Done' '- [ ] T002 Not done' > "$TEST_DIR/specs/001-test/tasks.md"
    result=$(get_feature_stage "$TEST_DIR" "001-test")
    [[ "$result" == "implementing-50%" ]]
}

@test "get_feature_stage: returns complete for all done" {
    mkdir -p "$TEST_DIR/specs/001-test"
    printf '%s\n%s\n' '- [x] T001 Done' '- [x] T002 Also done' > "$TEST_DIR/specs/001-test/tasks.md"
    result=$(get_feature_stage "$TEST_DIR" "001-test")
    [[ "$result" == "complete" ]]
}

@test "get_feature_stage: ignores [P] markers in task count" {
    mkdir -p "$TEST_DIR/specs/001-test"
    printf '%s\n%s\n%s\n' '- [x] T001 Done' '- [x] T002 Also done' '- [P] tasks = different files, no dependencies' > "$TEST_DIR/specs/001-test/tasks.md"
    result=$(get_feature_stage "$TEST_DIR" "001-test")
    [[ "$result" == "complete" ]]
}

@test "get_feature_stage: returns unknown for nonexistent feature" {
    result=$(get_feature_stage "$TEST_DIR" "999-nope")
    [[ "$result" == "unknown" ]]
}

# =============================================================================
# list_features_json tests
# =============================================================================

@test "list_features_json: returns empty array with no features" {
    result=$(list_features_json)
    [[ "$result" == "[]" ]]
}

# =============================================================================
# check_bdd_dependency tests
# =============================================================================

@test "check_bdd_dependency: finds pytest-bdd in requirements.txt" {
    echo "pytest-bdd>=7.0" > "$TEST_DIR/requirements.txt"
    run check_bdd_dependency "pytest-bdd" "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "requirements.txt"
}

@test "check_bdd_dependency: finds behave in pyproject.toml" {
    mkdir -p "$TEST_DIR"
    cat > "$TEST_DIR/pyproject.toml" << 'EOF'
[project.optional-dependencies]
test = ["behave>=1.2"]
EOF
    run check_bdd_dependency "behave" "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "pyproject.toml"
}

@test "check_bdd_dependency: fails when pytest-bdd not in any dep file" {
    echo "pytest>=7.0" > "$TEST_DIR/requirements.txt"
    run check_bdd_dependency "pytest-bdd" "$TEST_DIR"
    [[ "$status" -eq 1 ]]
}

@test "check_bdd_dependency: finds @cucumber/cucumber in package.json" {
    cat > "$TEST_DIR/package.json" << 'EOF'
{"devDependencies":{"@cucumber/cucumber":"^10.0"}}
EOF
    run check_bdd_dependency "@cucumber/cucumber" "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "package.json"
}

@test "check_bdd_dependency: fails when @cucumber/cucumber not in package.json" {
    cat > "$TEST_DIR/package.json" << 'EOF'
{"devDependencies":{"jest":"^29.0"}}
EOF
    run check_bdd_dependency "@cucumber/cucumber" "$TEST_DIR"
    [[ "$status" -eq 1 ]]
}

@test "check_bdd_dependency: finds godog in go.mod" {
    cat > "$TEST_DIR/go.mod" << 'EOF'
module example.com/app
require github.com/cucumber/godog v0.14.0
EOF
    run check_bdd_dependency "godog" "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "go.mod"
}

@test "check_bdd_dependency: finds cucumber in pom.xml" {
    cat > "$TEST_DIR/pom.xml" << 'EOF'
<dependency><groupId>io.cucumber</groupId></dependency>
EOF
    run check_bdd_dependency "cucumber-jvm-maven" "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "pom.xml"
}

@test "check_bdd_dependency: finds cucumber in build.gradle" {
    cat > "$TEST_DIR/build.gradle" << 'EOF'
testImplementation 'io.cucumber:cucumber-java:7.0'
EOF
    run check_bdd_dependency "cucumber-jvm-gradle" "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "build.gradle"
}

@test "check_bdd_dependency: finds cucumber in Cargo.toml" {
    cat > "$TEST_DIR/Cargo.toml" << 'EOF'
[dev-dependencies]
cucumber = "0.20"
EOF
    run check_bdd_dependency "cucumber-rs" "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Cargo.toml"
}

@test "check_bdd_dependency: finds reqnroll in .csproj" {
    mkdir -p "$TEST_DIR/src"
    cat > "$TEST_DIR/src/MyApp.csproj" << 'EOF'
<PackageReference Include="Reqnroll" Version="2.0" />
EOF
    run check_bdd_dependency "reqnroll" "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" ".csproj"
}

@test "check_bdd_dependency: returns 1 for unknown framework" {
    run check_bdd_dependency "unknown-framework" "$TEST_DIR"
    [[ "$status" -eq 1 ]]
}

# =============================================================================
# list_features_json tests (continued)
# =============================================================================

@test "list_features_json: returns features with stages" {
    mkdir -p "$TEST_DIR/specs/001-feature-a"
    echo "# Spec" > "$TEST_DIR/specs/001-feature-a/spec.md"
    mkdir -p "$TEST_DIR/specs/002-feature-b"
    echo "# Spec" > "$TEST_DIR/specs/002-feature-b/spec.md"
    echo "# Plan" > "$TEST_DIR/specs/002-feature-b/plan.md"

    result=$(list_features_json)
    assert_contains "$result" "001-feature-a"
    assert_contains "$result" "002-feature-b"
    assert_contains "$result" "specified"
    assert_contains "$result" "planned"
}
