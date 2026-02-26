#!/usr/bin/env bats
# Tests for check-prerequisites.sh

load 'test_helper'

CHECK_SCRIPT="$SCRIPTS_DIR/check-prerequisites.sh"

setup() {
    setup_test_dir
    # Set SPECIFY_FEATURE to simulate being on a feature
    export SPECIFY_FEATURE="001-test-feature"
    # Ensure we're in TEST_DIR for all tests
    cd "$TEST_DIR"
}

teardown() {
    unset SPECIFY_FEATURE
    teardown_test_dir
}

# =============================================================================
# Paths-only mode tests
# =============================================================================

@test "check-prerequisites: --paths-only returns paths without validation" {
    result=$("$CHECK_SCRIPT" --paths-only)

    assert_contains "$result" "REPO_ROOT:"
    assert_contains "$result" "BRANCH:"
    assert_contains "$result" "FEATURE_DIR:"
}

@test "check-prerequisites: --paths-only --json returns JSON paths" {
    result=$("$CHECK_SCRIPT" --paths-only --json)

    assert_contains "$result" '"REPO_ROOT"'
    assert_contains "$result" '"BRANCH"'
    assert_contains "$result" '"FEATURE_DIR"'
}

@test "check-prerequisites: --paths-only succeeds even without feature dir" {
    run "$CHECK_SCRIPT" --paths-only
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# Validation mode tests
# =============================================================================

@test "check-prerequisites: fails when feature dir missing" {
    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Feature directory not found"
}

@test "check-prerequisites: fails when constitution missing" {
    feature_dir=$(create_mock_feature "001-test-feature")
    rm CONSTITUTION.md

    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Constitution not found"
}

@test "check-prerequisites: fails when spec.md missing" {
    mkdir -p specs/001-test-feature

    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "spec.md not found"
}

@test "check-prerequisites: fails when plan.md missing" {
    mkdir -p specs/001-test-feature
    cp "$FIXTURES_DIR/spec.md" specs/001-test-feature/spec.md

    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "plan.md not found"
}

@test "check-prerequisites: succeeds with spec and plan" {
    create_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# Task requirement tests
# =============================================================================

@test "check-prerequisites: --require-tasks fails without tasks.md" {
    create_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --json --require-tasks
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "tasks.md not found"
}

@test "check-prerequisites: --require-tasks succeeds with tasks.md" {
    create_complete_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --json --require-tasks
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# Available docs tests
# =============================================================================

@test "check-prerequisites: lists available docs in JSON" {
    feature_dir=$(create_mock_feature "001-test-feature")

    # Add some optional docs
    echo "# Research" > "$feature_dir/research.md"
    mkdir -p "$feature_dir/contracts"
    echo "openapi: 3.0.0" > "$feature_dir/contracts/api.yaml"

    result=$("$CHECK_SCRIPT" --json)

    assert_contains "$result" '"AVAILABLE_DOCS"'
    assert_contains "$result" '"research.md"'
    assert_contains "$result" '"contracts/"'
}

@test "check-prerequisites: --include-tasks adds tasks to available docs" {
    create_complete_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --json --include-tasks)

    assert_contains "$result" '"tasks.md"'
}

@test "check-prerequisites: returns empty AVAILABLE_DOCS when no optional docs" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --json)

    # Should have empty array or no optional docs
    [[ "$result" == *'"AVAILABLE_DOCS":[]'* ]] || [[ "$result" != *'"research.md"'* ]]
}

# =============================================================================
# JSON output tests
# =============================================================================

@test "check-prerequisites: JSON output is valid JSON" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --json)

    # jq will fail if invalid JSON
    echo "$result" | jq . >/dev/null
}

@test "check-prerequisites: JSON contains FEATURE_DIR" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --json)

    feature_dir=$(echo "$result" | jq -r '.FEATURE_DIR')
    [[ "$feature_dir" == *"001-test-feature"* ]]
}

# =============================================================================
# Help tests
# =============================================================================

@test "check-prerequisites: --help shows usage" {
    run "$CHECK_SCRIPT" --help
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage:"
    assert_contains "$output" "--json"
    assert_contains "$output" "--phase"
    assert_contains "$output" "--require-tasks"
}

# =============================================================================
# Multi-feature / needs_selection tests
# =============================================================================

@test "check-prerequisites: exits 2 with needs_selection for multiple features" {
    unset SPECIFY_FEATURE
    # Remove active-feature if it exists
    rm -f "$TEST_DIR/.specify/active-feature"
    mkdir -p "$TEST_DIR/specs/001-feature-a"
    mkdir -p "$TEST_DIR/specs/002-feature-b"

    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 2 ]]
    assert_contains "$output" "needs_selection"
}

@test "check-prerequisites: needs_selection includes features list" {
    unset SPECIFY_FEATURE
    rm -f "$TEST_DIR/.specify/active-feature"
    mkdir -p "$TEST_DIR/specs/001-feature-a"
    mkdir -p "$TEST_DIR/specs/002-feature-b"

    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 2 ]]
    assert_contains "$output" "001-feature-a"
    assert_contains "$output" "002-feature-b"
}

@test "check-prerequisites: active-feature file resolves ambiguity" {
    unset SPECIFY_FEATURE
    # Create two features but set active-feature to one
    create_mock_feature "001-feature-a"
    create_mock_feature "002-feature-b"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-feature-a" > "$TEST_DIR/.specify/active-feature"

    run "$CHECK_SCRIPT" --json
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "001-feature-a"
}

# =============================================================================
# Phase mode tests
# =============================================================================

@test "check-prerequisites: --phase core returns paths without validation" {
    result=$("$CHECK_SCRIPT" --phase core)

    assert_contains "$result" "REPO_ROOT:"
    assert_contains "$result" "BRANCH:"
    assert_contains "$result" "FEATURE_DIR:"
}

@test "check-prerequisites: --phase core --json returns enriched JSON" {
    result=$("$CHECK_SCRIPT" --phase core --json)

    echo "$result" | jq . >/dev/null
    assert_contains "$result" '"phase":"core"'
    assert_contains "$result" '"constitution_mode":"none"'
    assert_contains "$result" '"FEATURE_DIR"'
    assert_contains "$result" '"REPO_ROOT"'
    assert_contains "$result" '"AVAILABLE_DOCS":[]'
}

@test "check-prerequisites: --phase core succeeds even without feature dir" {
    run "$CHECK_SCRIPT" --phase core
    [[ "$status" -eq 0 ]]
}

@test "check-prerequisites: --phase 03 validates constitution, spec, and plan" {
    create_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --phase 03 --json
    [[ "$status" -eq 0 ]]

    # Check enriched JSON fields
    echo "$output" | jq . >/dev/null
    assert_contains "$output" '"phase":"03"'
    assert_contains "$output" '"constitution_mode":"basic"'
    assert_contains "$output" '"validated"'
}

@test "check-prerequisites: --phase 03 fails without plan.md" {
    mkdir -p specs/001-test-feature
    cp "$FIXTURES_DIR/spec.md" specs/001-test-feature/spec.md

    run "$CHECK_SCRIPT" --phase 03 --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "plan.md not found"
}

@test "check-prerequisites: --phase clarify validates spec but not plan" {
    mkdir -p specs/001-test-feature
    cp "$FIXTURES_DIR/spec.md" specs/001-test-feature/spec.md
    # No plan.md, but clarify doesn't require it

    run "$CHECK_SCRIPT" --phase clarify --json
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"phase":"clarify"'
}

@test "check-prerequisites: --phase clarify succeeds without spec.md (utility phase)" {
    mkdir -p specs/001-test-feature

    run "$CHECK_SCRIPT" --phase clarify --json
    [[ "$status" -eq 0 ]]
}

@test "check-prerequisites: --phase clarify succeeds with only constitution (no feature dir)" {
    # Clarify can target constitution alone — no feature dir needed
    rm -rf specs/001-test-feature

    run "$CHECK_SCRIPT" --phase clarify --json
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"phase":"clarify"'
}

@test "check-prerequisites: --phase clarify succeeds with no artifacts at all" {
    # Even with nothing — clarify prerequisites pass (SKILL.md handles the error)
    rm -rf specs/001-test-feature
    rm -f CONSTITUTION.md

    run "$CHECK_SCRIPT" --phase clarify --json
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Constitution not found"
}

@test "check-prerequisites: --phase clarify soft constitution warns but continues" {
    mkdir -p specs/001-test-feature
    cp "$FIXTURES_DIR/spec.md" specs/001-test-feature/spec.md
    rm -f CONSTITUTION.md

    run "$CHECK_SCRIPT" --phase clarify --json
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"constitution_mode":"soft"'
    assert_contains "$output" "Constitution not found"
}

@test "check-prerequisites: --phase 07 requires tasks" {
    create_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --phase 07 --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "tasks.md not found"
}

@test "check-prerequisites: --phase 07 succeeds with tasks" {
    create_complete_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --phase 07 --json
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"phase":"07"'
    assert_contains "$output" '"tasks.md"'
}

@test "check-prerequisites: --phase 07 includes tasks in available docs" {
    create_complete_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase 07 --json)

    assert_contains "$result" '"tasks.md"'
}

@test "check-prerequisites: --phase 02 copies plan template" {
    mkdir -p specs/001-test-feature
    cp "$FIXTURES_DIR/spec.md" specs/001-test-feature/spec.md

    run "$CHECK_SCRIPT" --phase 02 --json
    [[ "$status" -eq 0 ]]

    # plan.md should have been created from template
    [[ -f "specs/001-test-feature/plan.md" ]]
    assert_contains "$output" '"plan_template_copied"'
}

@test "check-prerequisites: --phase 02 reports spec quality" {
    mkdir -p specs/001-test-feature
    cp "$FIXTURES_DIR/spec.md" specs/001-test-feature/spec.md

    result=$("$CHECK_SCRIPT" --phase 02 --json)

    assert_contains "$result" '"spec_quality"'
}

@test "check-prerequisites: --phase 08 requires tasks with implicit constitution" {
    create_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --phase 08 --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "tasks.md not found"
}

@test "check-prerequisites: --phase 08 succeeds with complete feature" {
    create_complete_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --phase 08 --json
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"phase":"08"'
    assert_contains "$output" '"constitution_mode":"implicit"'
}

@test "check-prerequisites: invalid phase errors" {
    run "$CHECK_SCRIPT" --phase invalid --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Unknown phase"
}

@test "check-prerequisites: enriched JSON has validated object" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase 03 --json)

    # Parse validated object
    constitution=$(echo "$result" | jq -r '.validated.constitution')
    spec=$(echo "$result" | jq -r '.validated.spec')
    plan=$(echo "$result" | jq -r '.validated.plan')
    tasks=$(echo "$result" | jq -r '.validated.tasks')

    [[ "$constitution" == "true" ]]
    [[ "$spec" == "true" ]]
    [[ "$plan" == "true" ]]
    [[ "$tasks" == "false" ]]
}

@test "check-prerequisites: enriched JSON has warnings array" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase 03 --json)

    # warnings should be a JSON array
    echo "$result" | jq '.warnings' >/dev/null
    warnings_type=$(echo "$result" | jq -r '.warnings | type')
    [[ "$warnings_type" == "array" ]]
}

@test "check-prerequisites: --phase 06 with soft checklist warns on incomplete" {
    create_complete_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/specs/001-test-feature/checklists"
    printf -- '- [ ] Item 1\n- [x] Item 2\n- [ ] Item 3\n' > "$TEST_DIR/specs/001-test-feature/checklists/quality.md"

    result=$("$CHECK_SCRIPT" --phase 06 --json)

    assert_contains "$result" "Checklists incomplete"
    assert_contains "$result" "Recommend"
    assert_contains "$result" '"checklist_checked":1'
    assert_contains "$result" '"checklist_total":3'
}

@test "check-prerequisites: --phase 07 with hard checklist warns strongly" {
    create_complete_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/specs/001-test-feature/checklists"
    printf -- '- [ ] Item 1\n- [x] Item 2\n' > "$TEST_DIR/specs/001-test-feature/checklists/quality.md"

    result=$("$CHECK_SCRIPT" --phase 07 --json)

    assert_contains "$result" "Must be 100%"
}

@test "check-prerequisites: legacy --paths-only emits deprecation warning" {
    run "$CHECK_SCRIPT" --paths-only
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "DEPRECATED"
}

@test "check-prerequisites: legacy --require-tasks emits deprecation warning" {
    create_complete_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --json --require-tasks
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "DEPRECATED"
}

@test "check-prerequisites: --phase with --project-root overrides repo root" {
    # Create a separate directory to use as project root
    alt_dir=$(mktemp -d)
    mkdir -p "$alt_dir/specs/001-test-feature"
    cp "$FIXTURES_DIR/spec.md" "$alt_dir/specs/001-test-feature/spec.md"
    cp "$FIXTURES_DIR/constitution.md" "$alt_dir/CONSTITUTION.md"

    result=$("$CHECK_SCRIPT" --phase clarify --json --project-root "$alt_dir")

    assert_contains "$result" "$alt_dir"
    rm -rf "$alt_dir"
}

# =============================================================================
# Status phase tests
# =============================================================================

@test "check-prerequisites: --phase status returns valid JSON" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase status --json)

    echo "$result" | jq . >/dev/null
}

@test "check-prerequisites: --phase status reports all artifact types" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase status --json)

    # Check artifacts object has all expected keys
    echo "$result" | jq '.artifacts.constitution' >/dev/null
    echo "$result" | jq '.artifacts.spec' >/dev/null
    echo "$result" | jq '.artifacts.plan' >/dev/null
    echo "$result" | jq '.artifacts.tasks' >/dev/null
    echo "$result" | jq '.artifacts.checklists' >/dev/null
    echo "$result" | jq '.artifacts.test_specs' >/dev/null
}

@test "check-prerequisites: --phase status ready_for is 05 for spec+plan" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase status --json)

    ready_for=$(echo "$result" | jq -r '.ready_for')
    [[ "$ready_for" == "05" ]]
}

@test "check-prerequisites: --phase status ready_for is 08 for complete feature" {
    create_complete_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase status --json)

    ready_for=$(echo "$result" | jq -r '.ready_for')
    [[ "$ready_for" == "08" ]]
}

@test "check-prerequisites: --phase status next_step is /iikit-05-tasks when plan exists but no tasks" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase status --json)

    next_step=$(echo "$result" | jq -r '.next_step')
    [[ "$next_step" == "/iikit-05-tasks" ]]
}

@test "check-prerequisites: --phase status next_step is /iikit-07-implement when tasks exist" {
    create_complete_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase status --json)

    next_step=$(echo "$result" | jq -r '.next_step')
    [[ "$next_step" == "/iikit-07-implement" ]]
}

@test "check-prerequisites: --phase status next_step is /iikit-00-constitution when no constitution" {
    create_mock_feature "001-test-feature"
    rm -f "$TEST_DIR/CONSTITUTION.md"

    result=$("$CHECK_SCRIPT" --phase status --json)

    next_step=$(echo "$result" | jq -r '.next_step')
    [[ "$next_step" == "/iikit-00-constitution" ]]
}

@test "check-prerequisites: --phase status next_step is /iikit-02-plan with spec but no plan" {
    mkdir -p specs/001-test-feature
    cp "$FIXTURES_DIR/spec.md" specs/001-test-feature/spec.md

    result=$("$CHECK_SCRIPT" --phase status --json)

    next_step=$(echo "$result" | jq -r '.next_step')
    [[ "$next_step" == "/iikit-02-plan" ]]
}

@test "check-prerequisites: --phase status clear_before is true for plan transition" {
    mkdir -p specs/001-test-feature
    cp "$FIXTURES_DIR/spec.md" specs/001-test-feature/spec.md

    result=$("$CHECK_SCRIPT" --phase status --json)

    clear_before=$(echo "$result" | jq -r '.clear_before')
    [[ "$clear_before" == "true" ]]
}

@test "check-prerequisites: --phase status clear_before is true for tasks transition" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase status --json)

    clear_before=$(echo "$result" | jq -r '.clear_before')
    [[ "$clear_before" == "true" ]]
}

@test "check-prerequisites: --phase status clear_before is true for implement transition" {
    create_complete_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase status --json)

    clear_before=$(echo "$result" | jq -r '.clear_before')
    [[ "$clear_before" == "true" ]]
}

@test "check-prerequisites: --phase status never exits on missing artifacts" {
    # Only constitution, no feature dir
    run "$CHECK_SCRIPT" --phase status --json
    [[ "$status" -eq 0 ]]
}

@test "check-prerequisites: --phase status still exits 2 for needs_selection" {
    unset SPECIFY_FEATURE
    rm -f "$TEST_DIR/.specify/active-feature"
    mkdir -p "$TEST_DIR/specs/001-feature-a"
    mkdir -p "$TEST_DIR/specs/002-feature-b"

    run "$CHECK_SCRIPT" --phase status --json
    [[ "$status" -eq 2 ]]
    assert_contains "$output" "needs_selection"
}

@test "check-prerequisites: --phase status feature_stage matches get_feature_stage" {
    create_complete_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase status --json)

    stage=$(echo "$result" | jq -r '.feature_stage')
    # Fixture tasks.md has 2/7 done = implementing-28%
    [[ "$stage" == "implementing-28%" ]]
}

@test "check-prerequisites: --phase status reports spec quality in artifacts" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase status --json)

    quality=$(echo "$result" | jq -r '.artifacts.spec.quality')
    [[ "$quality" =~ ^[0-9]+$ ]]
    [[ "$quality" -gt 0 ]]
}

@test "check-prerequisites: --phase status reports incomplete checklists" {
    create_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/specs/001-test-feature/checklists"
    printf -- '- [ ] Item 1\n- [x] Item 2\n- [ ] Item 3\n' > "$TEST_DIR/specs/001-test-feature/checklists/quality.md"

    result=$("$CHECK_SCRIPT" --phase status --json)

    checked=$(echo "$result" | jq -r '.checklist_checked')
    total=$(echo "$result" | jq -r '.checklist_total')
    complete=$(echo "$result" | jq -r '.artifacts.checklists.complete')
    [[ "$checked" == "1" ]]
    [[ "$total" == "3" ]]
    [[ "$complete" == "false" ]]
}

@test "check-prerequisites: --phase status text mode output" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase status)

    assert_contains "$result" "Phase: status"
    assert_contains "$result" "Feature stage:"
    assert_contains "$result" "Ready for:"
    assert_contains "$result" "Next step:"
    assert_contains "$result" "Artifacts:"
}

@test "check-prerequisites: --phase status has validated object (backward compat)" {
    create_mock_feature "001-test-feature"

    result=$("$CHECK_SCRIPT" --phase status --json)

    # validated object should be present
    echo "$result" | jq '.validated.constitution' >/dev/null
    echo "$result" | jq '.validated.spec' >/dev/null
    echo "$result" | jq '.validated.plan' >/dev/null
    echo "$result" | jq '.validated.tasks' >/dev/null
}

# =============================================================================
# Testify enforcement when TDD mandatory
# =============================================================================

@test "check-prerequisites: --phase 05 fails when TDD mandatory and no testify artifacts" {
    create_mock_feature "001-test-feature"

    # Remove .feature files added by create_mock_feature
    rm -rf "$TEST_DIR/specs/001-test-feature/tests/features"

    # Constitution fixture already has "TDD Required: Test-first development MUST be used"

    run "$CHECK_SCRIPT" --phase 05 --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "TDD is mandatory"
    assert_contains "$output" "/iikit-04-testify"
}

@test "check-prerequisites: --phase 05 passes when TDD mandatory and .feature files exist" {
    # create_mock_feature already adds .feature files
    create_mock_feature "001-test-feature"

    run "$CHECK_SCRIPT" --phase 05 --json
    [[ "$status" -eq 0 ]]
}

@test "check-prerequisites: --phase 05 passes when TDD mandatory and cached in context.json" {
    create_mock_feature "001-test-feature"

    # Write cached TDD determination to .specify/context.json
    mkdir -p "$TEST_DIR/.specify"
    echo '{"tdd_determination": "mandatory"}' > "$TEST_DIR/.specify/context.json"

    run "$CHECK_SCRIPT" --phase 05 --json
    [[ "$status" -eq 0 ]]
}

@test "check-prerequisites: --phase 05 passes when TDD not mandatory and no testify artifacts" {
    create_mock_feature "001-test-feature"

    # Replace constitution with one that doesn't require TDD
    cat > "$TEST_DIR/CONSTITUTION.md" << 'EOF'
# Constitution
## Core Principles
- **Quality First**: Code SHOULD be tested
- **Documentation**: All public APIs SHOULD have documentation
- **Simplicity**: Keep it simple
EOF

    run "$CHECK_SCRIPT" --phase 05 --json
    [[ "$status" -eq 0 ]]
}

@test "check-prerequisites: --phase 05 fails when TDD mandatory and no testify artifacts (complete feature)" {
    create_complete_mock_feature "001-test-feature"

    # Remove test artifacts
    rm -rf "$TEST_DIR/specs/001-test-feature/tests"

    run "$CHECK_SCRIPT" --phase 05 --json
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "TDD is mandatory"
}

# =============================================================================
# Status next_step for incomplete checklists
# =============================================================================

@test "check-prerequisites: --phase status next_step skips checklist (optional) when incomplete" {
    create_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/specs/001-test-feature/checklists"
    printf -- '- [ ] Item 1\n- [x] Item 2\n- [ ] Item 3\n' > "$TEST_DIR/specs/001-test-feature/checklists/quality.md"

    result=$("$CHECK_SCRIPT" --phase status --json)

    # Checklist is optional — next-step.sh skips past it on the mandatory path
    next_step=$(echo "$result" | jq -r '.next_step')
    [[ "$next_step" == "/iikit-05-tasks" ]]
}
