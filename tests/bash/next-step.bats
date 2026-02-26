#!/usr/bin/env bats
# Tests for next-step.sh — single source of truth for next-step determination

load 'test_helper'

NEXT_STEP_SCRIPT="$SCRIPTS_DIR/next-step.sh"

setup() {
    setup_test_dir
    export SPECIFY_FEATURE="001-test-feature"
    cd "$TEST_DIR"
}

teardown() {
    unset SPECIFY_FEATURE
    teardown_test_dir
}

# =============================================================================
# Argument validation
# =============================================================================

@test "next-step: errors without --phase" {
    run "$NEXT_STEP_SCRIPT" --json
    [[ "$status" -ne 0 ]]
}

@test "next-step: errors without --json" {
    run "$NEXT_STEP_SCRIPT" --phase 00
    [[ "$status" -ne 0 ]]
}

# =============================================================================
# Phase-based transitions (mandatory path: 00→01→02→[04 if TDD]→05→07)
# =============================================================================

@test "next-step: phase 00 → /iikit-01-specify" {
    result=$("$NEXT_STEP_SCRIPT" --phase 00 --json)
    assert_json_field "$result" "next_step" "/iikit-01-specify"
    assert_json_field "$result" "next_phase" "01"
}

@test "next-step: phase 01 → /iikit-02-plan" {
    result=$("$NEXT_STEP_SCRIPT" --phase 01 --json)
    assert_json_field "$result" "next_step" "/iikit-02-plan"
    assert_json_field "$result" "next_phase" "02"
}

@test "next-step: phase 02 → /iikit-05-tasks when TDD not mandatory" {
    # Default fixture constitution mandates TDD, override with no-TDD constitution
    cp "$FIXTURES_DIR/constitution-no-tdd.md" "$TEST_DIR/CONSTITUTION.md"

    result=$("$NEXT_STEP_SCRIPT" --phase 02 --json)
    assert_json_field "$result" "next_step" "/iikit-05-tasks"
    assert_json_field "$result" "next_phase" "05"
}

@test "next-step: phase 02 → /iikit-04-testify when TDD mandatory" {
    # Default fixture constitution mandates TDD
    result=$("$NEXT_STEP_SCRIPT" --phase 02 --json)
    assert_json_field "$result" "next_step" "/iikit-04-testify"
    assert_json_field "$result" "next_phase" "04"
}

@test "next-step: phase 03 → /iikit-05-tasks when TDD not mandatory" {
    cp "$FIXTURES_DIR/constitution-no-tdd.md" "$TEST_DIR/CONSTITUTION.md"

    result=$("$NEXT_STEP_SCRIPT" --phase 03 --json)
    assert_json_field "$result" "next_step" "/iikit-05-tasks"
    assert_json_field "$result" "next_phase" "05"
}

@test "next-step: phase 03 → /iikit-04-testify when TDD mandatory and no test specs" {
    result=$("$NEXT_STEP_SCRIPT" --phase 03 --json)
    assert_json_field "$result" "next_step" "/iikit-04-testify"
    assert_json_field "$result" "next_phase" "04"
}

@test "next-step: phase 03 → /iikit-05-tasks when TDD mandatory but test specs exist" {
    create_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-test-feature" > "$TEST_DIR/.specify/active-feature"

    result=$("$NEXT_STEP_SCRIPT" --phase 03 --json)
    # create_mock_feature adds .feature files, so test specs exist
    assert_json_field "$result" "next_step" "/iikit-05-tasks"
}

@test "next-step: phase 04 → /iikit-05-tasks" {
    result=$("$NEXT_STEP_SCRIPT" --phase 04 --json)
    assert_json_field "$result" "next_step" "/iikit-05-tasks"
    assert_json_field "$result" "next_phase" "05"
}

@test "next-step: phase 05 → /iikit-07-implement" {
    result=$("$NEXT_STEP_SCRIPT" --phase 05 --json)
    assert_json_field "$result" "next_step" "/iikit-07-implement"
    assert_json_field "$result" "next_phase" "07"
}

@test "next-step: phase 06 → /iikit-07-implement" {
    result=$("$NEXT_STEP_SCRIPT" --phase 06 --json)
    assert_json_field "$result" "next_step" "/iikit-07-implement"
    assert_json_field "$result" "next_phase" "07"
}

@test "next-step: phase 07 → /iikit-07-implement (resume) when feature incomplete" {
    create_complete_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-test-feature" > "$TEST_DIR/.specify/active-feature"

    result=$("$NEXT_STEP_SCRIPT" --phase 07 --json)
    # Fixture tasks.md has 2/7 done, so feature is incomplete
    assert_json_field "$result" "next_step" "/iikit-07-implement"
    assert_json_field "$result" "next_phase" "07"
}

@test "next-step: phase 07 → null when feature complete" {
    mkdir -p "$TEST_DIR/specs/001-test-feature"
    printf '%s\n%s\n' '- [x] T001 Done' '- [x] T002 Also done' > "$TEST_DIR/specs/001-test-feature/tasks.md"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-test-feature" > "$TEST_DIR/.specify/active-feature"

    result=$("$NEXT_STEP_SCRIPT" --phase 07 --json)
    assert_json_field "$result" "next_step" "null"
    assert_json_field "$result" "next_phase" "null"
}

@test "next-step: phase 08 → null (terminal)" {
    result=$("$NEXT_STEP_SCRIPT" --phase 08 --json)
    assert_json_field "$result" "next_step" "null"
    assert_json_field "$result" "next_phase" "null"
}

@test "next-step: bugfix → /iikit-07-implement always" {
    result=$("$NEXT_STEP_SCRIPT" --phase bugfix --json)
    assert_json_field "$result" "next_step" "/iikit-07-implement"
    assert_json_field "$result" "next_phase" "07"
}

# =============================================================================
# Artifact-state fallback (clarify, core, status)
# =============================================================================

@test "next-step: status fallback → /iikit-00-constitution when no constitution" {
    rm -f "$TEST_DIR/CONSTITUTION.md"

    result=$("$NEXT_STEP_SCRIPT" --phase status --json)
    assert_json_field "$result" "next_step" "/iikit-00-constitution"
    assert_json_field "$result" "next_phase" "00"
}

@test "next-step: status fallback → /iikit-01-specify when no feature" {
    result=$("$NEXT_STEP_SCRIPT" --phase status --json)
    # No feature directory exists for SPECIFY_FEATURE
    assert_json_field "$result" "next_step" "/iikit-01-specify"
    assert_json_field "$result" "next_phase" "01"
}

@test "next-step: status fallback → /iikit-02-plan when spec exists but no plan" {
    mkdir -p "$TEST_DIR/specs/001-test-feature"
    cp "$FIXTURES_DIR/spec.md" "$TEST_DIR/specs/001-test-feature/spec.md"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-test-feature" > "$TEST_DIR/.specify/active-feature"

    result=$("$NEXT_STEP_SCRIPT" --phase status --json)
    assert_json_field "$result" "next_step" "/iikit-02-plan"
    assert_json_field "$result" "next_phase" "02"
}

@test "next-step: status fallback → /iikit-04-testify when TDD mandatory and no test specs" {
    mkdir -p "$TEST_DIR/specs/001-test-feature"
    cp "$FIXTURES_DIR/spec.md" "$TEST_DIR/specs/001-test-feature/spec.md"
    cp "$FIXTURES_DIR/plan.md" "$TEST_DIR/specs/001-test-feature/plan.md"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-test-feature" > "$TEST_DIR/.specify/active-feature"
    # Default constitution mandates TDD, no test specs exist

    result=$("$NEXT_STEP_SCRIPT" --phase status --json)
    assert_json_field "$result" "next_step" "/iikit-04-testify"
    assert_json_field "$result" "next_phase" "04"
}

@test "next-step: status fallback → /iikit-05-tasks when plan exists but no tasks" {
    create_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-test-feature" > "$TEST_DIR/.specify/active-feature"
    # create_mock_feature adds .feature files so TDD gate passes

    result=$("$NEXT_STEP_SCRIPT" --phase status --json)
    assert_json_field "$result" "next_step" "/iikit-05-tasks"
    assert_json_field "$result" "next_phase" "05"
}

@test "next-step: status fallback → /iikit-07-implement when tasks exist and incomplete" {
    create_complete_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-test-feature" > "$TEST_DIR/.specify/active-feature"

    result=$("$NEXT_STEP_SCRIPT" --phase status --json)
    assert_json_field "$result" "next_step" "/iikit-07-implement"
    assert_json_field "$result" "next_phase" "07"
}

@test "next-step: status fallback → null when feature complete" {
    create_mock_feature "001-test-feature"
    printf '%s\n%s\n' '- [x] T001 Done' '- [x] T002 Also done' > "$TEST_DIR/specs/001-test-feature/tasks.md"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-test-feature" > "$TEST_DIR/.specify/active-feature"

    result=$("$NEXT_STEP_SCRIPT" --phase status --json)
    assert_json_field "$result" "next_step" "null"
}

@test "next-step: clarify uses artifact-state fallback" {
    create_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-test-feature" > "$TEST_DIR/.specify/active-feature"

    result=$("$NEXT_STEP_SCRIPT" --phase clarify --json)
    # spec + plan exist, TDD mandatory, .feature files present → tasks
    assert_json_field "$result" "next_step" "/iikit-05-tasks"
}

@test "next-step: core uses artifact-state fallback" {
    result=$("$NEXT_STEP_SCRIPT" --phase core --json)
    # No feature dir → specify
    assert_json_field "$result" "next_step" "/iikit-01-specify"
}

# =============================================================================
# JSON output structure
# =============================================================================

@test "next-step: output is valid JSON" {
    result=$("$NEXT_STEP_SCRIPT" --phase 00 --json)
    echo "$result" | jq . >/dev/null
}

@test "next-step: output contains all required fields" {
    result=$("$NEXT_STEP_SCRIPT" --phase 01 --json)

    echo "$result" | jq '.current_phase' >/dev/null
    echo "$result" | jq '.next_step' >/dev/null
    echo "$result" | jq '.next_phase' >/dev/null
    echo "$result" | jq '.clear_before' >/dev/null
    echo "$result" | jq '.clear_after' >/dev/null
    echo "$result" | jq '.model_tier' >/dev/null
    echo "$result" | jq '.feature_stage' >/dev/null
    echo "$result" | jq '.tdd_mandatory' >/dev/null
    echo "$result" | jq '.alt_steps' >/dev/null
}

@test "next-step: current_phase matches input" {
    result=$("$NEXT_STEP_SCRIPT" --phase 03 --json)
    assert_json_field "$result" "current_phase" "03"
}

# =============================================================================
# Clear logic
# =============================================================================

@test "next-step: clear_after true for phase 02 (plan consumed context)" {
    result=$("$NEXT_STEP_SCRIPT" --phase 02 --json)
    assert_json_field "$result" "clear_after" "true"
}

@test "next-step: clear_after true for phase 03 (checklist consumed context)" {
    result=$("$NEXT_STEP_SCRIPT" --phase 03 --json)
    assert_json_field "$result" "clear_after" "true"
}

@test "next-step: clear_after true for phase 07 (implementation consumed context)" {
    result=$("$NEXT_STEP_SCRIPT" --phase 07 --json)
    assert_json_field "$result" "clear_after" "true"
}

@test "next-step: clear_after true for clarify (Q&A consumed context)" {
    result=$("$NEXT_STEP_SCRIPT" --phase clarify --json)
    assert_json_field "$result" "clear_after" "true"
}

@test "next-step: clear_after false for phase 00" {
    result=$("$NEXT_STEP_SCRIPT" --phase 00 --json)
    assert_json_field "$result" "clear_after" "false"
}

@test "next-step: clear_after false for phase 01" {
    result=$("$NEXT_STEP_SCRIPT" --phase 01 --json)
    assert_json_field "$result" "clear_after" "false"
}

@test "next-step: clear_before true when next is plan (02)" {
    result=$("$NEXT_STEP_SCRIPT" --phase 01 --json)
    # next_phase is 02 (plan), so clear_before should be true
    assert_json_field "$result" "clear_before" "true"
}

@test "next-step: clear_before true when next is implement (07)" {
    result=$("$NEXT_STEP_SCRIPT" --phase 05 --json)
    # next_phase is 07 (implement), so clear_before should be true
    assert_json_field "$result" "clear_before" "true"
}

@test "next-step: clear_before false when next is specify (01)" {
    result=$("$NEXT_STEP_SCRIPT" --phase 00 --json)
    # next_phase is 01 (specify), so clear_before should be false
    assert_json_field "$result" "clear_before" "false"
}

# =============================================================================
# Model tier
# =============================================================================

@test "next-step: model_tier heavy for plan (02)" {
    result=$("$NEXT_STEP_SCRIPT" --phase 01 --json)
    # next is plan (02) → heavy
    assert_json_field "$result" "model_tier" "heavy"
}

@test "next-step: model_tier medium for specify (01)" {
    result=$("$NEXT_STEP_SCRIPT" --phase 00 --json)
    # next is specify (01) → medium
    assert_json_field "$result" "model_tier" "medium"
}

@test "next-step: model_tier medium for tasks (05)" {
    result=$("$NEXT_STEP_SCRIPT" --phase 04 --json)
    # next is tasks (05) → medium
    assert_json_field "$result" "model_tier" "medium"
}

@test "next-step: model_tier heavy for implement (07)" {
    result=$("$NEXT_STEP_SCRIPT" --phase 05 --json)
    # next is implement (07) → heavy
    assert_json_field "$result" "model_tier" "heavy"
}

@test "next-step: model_tier null when workflow complete" {
    result=$("$NEXT_STEP_SCRIPT" --phase 08 --json)
    assert_json_field "$result" "model_tier" "null"
}

# =============================================================================
# TDD determination
# =============================================================================

@test "next-step: tdd_mandatory true with TDD constitution" {
    result=$("$NEXT_STEP_SCRIPT" --phase 00 --json)
    # Default fixture constitution mandates TDD
    assert_json_field "$result" "tdd_mandatory" "true"
}

@test "next-step: tdd_mandatory false with no-TDD constitution" {
    cp "$FIXTURES_DIR/constitution-no-tdd.md" "$TEST_DIR/CONSTITUTION.md"

    result=$("$NEXT_STEP_SCRIPT" --phase 00 --json)
    assert_json_field "$result" "tdd_mandatory" "false"
}

@test "next-step: tdd_mandatory from cached context.json" {
    # Override constitution with no-TDD, but cache says mandatory
    cp "$FIXTURES_DIR/constitution-no-tdd.md" "$TEST_DIR/CONSTITUTION.md"
    mkdir -p "$TEST_DIR/.specify"
    echo '{"tdd_determination": "mandatory"}' > "$TEST_DIR/.specify/context.json"

    result=$("$NEXT_STEP_SCRIPT" --phase 02 --json)
    assert_json_field "$result" "tdd_mandatory" "true"
    assert_json_field "$result" "next_step" "/iikit-04-testify"
}

# =============================================================================
# Alt steps
# =============================================================================

@test "next-step: alt_steps includes clarify when artifacts exist" {
    create_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-test-feature" > "$TEST_DIR/.specify/active-feature"

    result=$("$NEXT_STEP_SCRIPT" --phase 04 --json)
    alt_count=$(echo "$result" | jq '.alt_steps | length')
    [[ "$alt_count" -gt 0 ]]

    first_alt=$(echo "$result" | jq -r '.alt_steps[0].step')
    [[ "$first_alt" == "/iikit-clarify" ]]
}

@test "next-step: alt_steps empty when no artifacts" {
    result=$("$NEXT_STEP_SCRIPT" --phase 00 --json)
    alt_count=$(echo "$result" | jq '.alt_steps | length')
    [[ "$alt_count" -eq 0 ]]
}

@test "next-step: alt_steps includes checklist after plan (phase 02)" {
    cp "$FIXTURES_DIR/constitution-no-tdd.md" "$TEST_DIR/CONSTITUTION.md"

    result=$("$NEXT_STEP_SCRIPT" --phase 02 --json)
    alts=$(echo "$result" | jq -r '.alt_steps[].step')
    [[ "$alts" == *"/iikit-03-checklist"* ]]
}

@test "next-step: alt_steps includes testify after plan when TDD not mandatory" {
    cp "$FIXTURES_DIR/constitution-no-tdd.md" "$TEST_DIR/CONSTITUTION.md"

    result=$("$NEXT_STEP_SCRIPT" --phase 02 --json)
    alts=$(echo "$result" | jq -r '.alt_steps[].step')
    [[ "$alts" == *"/iikit-04-testify"* ]]
}

@test "next-step: alt_steps does not include testify after plan when TDD mandatory" {
    # Default constitution mandates TDD — testify is the main step, not alt
    result=$("$NEXT_STEP_SCRIPT" --phase 02 --json)
    alts=$(echo "$result" | jq -r '.alt_steps[].step' 2>/dev/null || echo "")
    [[ "$alts" != *"/iikit-04-testify"* ]]
}

@test "next-step: alt_steps includes analyze after tasks (phase 05)" {
    result=$("$NEXT_STEP_SCRIPT" --phase 05 --json)
    alts=$(echo "$result" | jq -r '.alt_steps[].step')
    [[ "$alts" == *"/iikit-06-analyze"* ]]
}

@test "next-step: alt_steps includes tasks-to-issues after implement when complete" {
    mkdir -p "$TEST_DIR/specs/001-test-feature"
    printf '%s\n%s\n' '- [x] T001 Done' '- [x] T002 Also done' > "$TEST_DIR/specs/001-test-feature/tasks.md"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-test-feature" > "$TEST_DIR/.specify/active-feature"

    result=$("$NEXT_STEP_SCRIPT" --phase 07 --json)
    alts=$(echo "$result" | jq -r '.alt_steps[].step')
    [[ "$alts" == *"/iikit-08-taskstoissues"* ]]
}

# =============================================================================
# Feature stage
# =============================================================================

@test "next-step: feature_stage reflects actual feature state" {
    create_complete_mock_feature "001-test-feature"
    mkdir -p "$TEST_DIR/.specify"
    echo "001-test-feature" > "$TEST_DIR/.specify/active-feature"

    result=$("$NEXT_STEP_SCRIPT" --phase status --json)
    stage=$(echo "$result" | jq -r '.feature_stage')
    [[ "$stage" == "implementing-28%" ]]
}

@test "next-step: feature_stage unknown when no feature" {
    result=$("$NEXT_STEP_SCRIPT" --phase 00 --json)
    assert_json_field "$result" "feature_stage" "unknown"
}

# =============================================================================
# --project-root override
# =============================================================================

@test "next-step: --project-root overrides repo root" {
    alt_dir=$(mktemp -d)
    mkdir -p "$alt_dir/specs/001-test-feature"
    cp "$FIXTURES_DIR/spec.md" "$alt_dir/specs/001-test-feature/spec.md"
    cp "$FIXTURES_DIR/constitution.md" "$alt_dir/CONSTITUTION.md"
    mkdir -p "$alt_dir/.specify"
    echo "001-test-feature" > "$alt_dir/.specify/active-feature"

    result=$("$NEXT_STEP_SCRIPT" --phase status --json --project-root "$alt_dir")
    assert_json_field "$result" "next_step" "/iikit-02-plan"
    rm -rf "$alt_dir"
}

# =============================================================================
# Integration: check-prerequisites.sh uses next-step.sh
# =============================================================================

@test "next-step: check-prerequisites status includes model_tier" {
    create_mock_feature "001-test-feature"

    result=$("$SCRIPTS_DIR/check-prerequisites.sh" --phase status --json)
    echo "$result" | jq '.model_tier' >/dev/null
}
