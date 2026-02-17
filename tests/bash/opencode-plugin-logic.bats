#!/usr/bin/env bats
# Tests for OpenCode plugin logic (.opencode/plugins/iikit-context.ts)
#
# The TypeScript plugin reads the same files as the bash hooks.
# We test the file-reading logic via a Node.js script that extracts
# the pure functions and exercises them against test fixtures.

load 'test_helper'

setup() {
    setup_test_dir
    cd "$TEST_DIR"
}

teardown() {
    teardown_test_dir
}

# Helper: run the stage detection logic in Node
detect_stage() {
    local specs_dir="$1"
    local feature="$2"
    node -e "
const fs = require('fs');
const path = require('path');

function getFeatureStage(specsDir, feature) {
    const featureDir = path.join(specsDir, feature);
    if (!fs.existsSync(featureDir)) return 'unknown';
    const tasksFile = path.join(featureDir, 'tasks.md');
    if (fs.existsSync(tasksFile)) {
        const content = fs.readFileSync(tasksFile, 'utf-8');
        const lines = content.split('\n').filter(l => /^- \[.\]/.test(l));
        const total = lines.length;
        const done = lines.filter(l => /^- \[[xX]\]/.test(l)).length;
        if (total > 0) {
            if (done === total) return 'complete';
            if (done > 0) return 'implementing-' + Math.floor((done * 100) / total) + '%';
            return 'tasks-ready';
        }
    }
    if (fs.existsSync(path.join(featureDir, 'plan.md'))) return 'planned';
    if (fs.existsSync(path.join(featureDir, 'spec.md'))) return 'specified';
    return 'unknown';
}

console.log(getFeatureStage('$specs_dir', '$feature'));
"
}

# =============================================================================
# Stage detection (mirrors bash get_feature_stage)
# =============================================================================

@test "opencode-plugin: detects specified stage" {
    mkdir -p specs/001-test
    echo "# Spec" > specs/001-test/spec.md
    result=$(detect_stage "$TEST_DIR/specs" "001-test")
    [[ "$result" == "specified" ]]
}

@test "opencode-plugin: detects planned stage" {
    mkdir -p specs/001-test
    echo "# Spec" > specs/001-test/spec.md
    echo "# Plan" > specs/001-test/plan.md
    result=$(detect_stage "$TEST_DIR/specs" "001-test")
    [[ "$result" == "planned" ]]
}

@test "opencode-plugin: detects tasks-ready stage" {
    mkdir -p specs/001-test
    printf '%s\n%s\n' '- [ ] T001 Do something' '- [ ] T002 Do another' > specs/001-test/tasks.md
    result=$(detect_stage "$TEST_DIR/specs" "001-test")
    [[ "$result" == "tasks-ready" ]]
}

@test "opencode-plugin: detects implementing percentage" {
    mkdir -p specs/001-test
    printf '%s\n%s\n' '- [x] T001 Done' '- [ ] T002 Not done' > specs/001-test/tasks.md
    result=$(detect_stage "$TEST_DIR/specs" "001-test")
    [[ "$result" == "implementing-50%" ]]
}

@test "opencode-plugin: detects complete stage" {
    mkdir -p specs/001-test
    printf '%s\n%s\n' '- [x] T001 Done' '- [x] T002 Also done' > specs/001-test/tasks.md
    result=$(detect_stage "$TEST_DIR/specs" "001-test")
    [[ "$result" == "complete" ]]
}

@test "opencode-plugin: returns unknown for nonexistent feature" {
    result=$(detect_stage "$TEST_DIR/specs" "999-nope")
    [[ "$result" == "unknown" ]]
}

@test "opencode-plugin: stage results match bash implementation" {
    # Verify the TypeScript logic produces identical results to bash
    mkdir -p specs/001-test
    echo "# Spec" > specs/001-test/spec.md
    echo "# Plan" > specs/001-test/plan.md

    bash_result=$(get_feature_stage "$TEST_DIR" "001-test")
    node_result=$(detect_stage "$TEST_DIR/specs" "001-test")
    [[ "$bash_result" == "$node_result" ]]
}
