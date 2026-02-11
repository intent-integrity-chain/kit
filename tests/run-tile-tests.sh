#!/usr/bin/env bash
#
# Intent Integrity Kit Tile Integration Tests
#
# Tests the Tessl-packaged tile to ensure it works after installation.
#
# Usage:
#   ./tiles/intent-integrity-kit/tests/run-tile-tests.sh [--from-registry|--from-local]
#

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

TEST_DIR=""
TILE_SOURCE="registry"
ORIGINAL_DIR=""

TESTS_WARNED=0

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)); }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((TESTS_WARNED++)); }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

run_test() {
    local name="$1"
    local cmd="$2"
    ((TESTS_RUN++))

    if eval "$cmd" >/dev/null 2>&1; then
        log_pass "$name"
        return 0
    else
        log_fail "$name"
        return 1
    fi
}

setup() {
    log_section "Setup"
    ORIGINAL_DIR=$(pwd)
    TEST_DIR=$(mktemp -d)
    log_info "Test dir: $TEST_DIR"

    cd "$TEST_DIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "# Test" > README.md
    git add README.md
    git commit -qm "init"

    echo '{"tiles":{}}' > tessl.json

    if [[ "$TILE_SOURCE" == "local" ]]; then
        log_info "Installing from local..."
        tessl install "file:$ORIGINAL_DIR/tiles/intent-integrity-kit" 2>&1 | grep -v "^-"
    else
        log_info "Installing from registry (latest)..."
        # Note: May need to specify version if recently published
        tessl install tessl-labs/intent-integrity-kit 2>&1 | grep -v "^-"
        if [[ ! -d ".tessl/tiles/tessl-labs/intent-integrity-kit" ]]; then
            log_info "Retrying with explicit version..."
            tessl install tessl-labs/intent-integrity-kit@0.7.0 2>&1 | grep -v "^-" || \
            tessl install tessl-labs/intent-integrity-kit@0.6.5 2>&1 | grep -v "^-"
        fi
    fi
}

teardown() {
    cd "$ORIGINAL_DIR" 2>/dev/null || true
    [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

test_scripts_exist() {
    log_section "Bash Scripts Exist"
    local bash_base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash"

    run_test "check-prerequisites.sh exists" "[[ -f '$bash_base/check-prerequisites.sh' ]]"
    run_test "create-new-feature.sh exists" "[[ -f '$bash_base/create-new-feature.sh' ]]"
    run_test "setup-plan.sh exists" "[[ -f '$bash_base/setup-plan.sh' ]]"
    run_test "testify-tdd.sh exists" "[[ -f '$bash_base/testify-tdd.sh' ]]"
    run_test "common.sh exists" "[[ -f '$bash_base/common.sh' ]]"
    run_test "update-agent-context.sh exists" "[[ -f '$bash_base/update-agent-context.sh' ]]"
}

test_powershell_scripts_exist() {
    log_section "PowerShell Scripts Exist (known: registry strips .ps1)"
    local ps_base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell"

    # PowerShell scripts are stripped by the tessl registry on publish.
    # This is a known limitation — warn instead of fail.
    local ps_scripts=(
        "check-prerequisites.ps1"
        "create-new-feature.ps1"
        "setup-plan.ps1"
        "testify-tdd.ps1"
        "common.ps1"
        "update-agent-context.ps1"
        "init-project.ps1"
        "setup-windows-links.ps1"
    )

    for script in "${ps_scripts[@]}"; do
        ((TESTS_RUN++))
        if [[ -f "$ps_base/$script" ]]; then
            log_pass "$script exists"
        else
            log_warn "$script missing (tessl registry strips .ps1 files)"
        fi
    done
}

test_scripts_executable() {
    log_section "Scripts Execute with Bash"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash"

    ((TESTS_RUN++))
    if bash "$base/check-prerequisites.sh" --help >/dev/null 2>&1; then
        log_pass "check-prerequisites.sh --help"
    else
        log_fail "check-prerequisites.sh --help"
    fi

    ((TESTS_RUN++))
    if bash "$base/create-new-feature.sh" --help >/dev/null 2>&1; then
        log_pass "create-new-feature.sh --help"
    else
        log_fail "create-new-feature.sh --help"
    fi

    ((TESTS_RUN++))
    if bash "$base/setup-plan.sh" --help >/dev/null 2>&1; then
        log_pass "setup-plan.sh --help"
    else
        log_fail "setup-plan.sh --help"
    fi

    # testify-tdd.sh shows usage on unknown command (exits 1 but runs)
    ((TESTS_RUN++))
    local output
    output=$(bash "$base/testify-tdd.sh" unknown 2>&1) || true
    if echo "$output" | grep -q 'Available commands'; then
        log_pass "testify-tdd.sh runs"
    else
        log_fail "testify-tdd.sh runs (output: ${output:0:50}...)"
    fi
}

test_templates_exist() {
    log_section "Templates Exist"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/templates"

    run_test "constitution-template.md" "[[ -f '$base/constitution-template.md' ]]"
    run_test "spec-template.md" "[[ -f '$base/spec-template.md' ]]"
    run_test "plan-template.md" "[[ -f '$base/plan-template.md' ]]"
    run_test "tasks-template.md" "[[ -f '$base/tasks-template.md' ]]"
    run_test "checklist-template.md" "[[ -f '$base/checklist-template.md' ]]"
    run_test "testspec-template.md" "[[ -f '$base/testspec-template.md' ]]"
}

test_skills_exist() {
    log_section "Skills Exist"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills"

    # Check iikit-core exists
    run_test "iikit-core skill" "[[ -d '$base/iikit-core' && -f '$base/iikit-core/SKILL.md' ]]"

    for i in 00 01 02 03 04 05 06 07 08 09; do
        local skill=$(ls -d "$base"/iikit-${i}-* 2>/dev/null | head -1)
        run_test "iikit-${i}-* skill" "[[ -d '$skill' && -f '$skill/SKILL.md' ]]"
    done
}

test_workflow_order() {
    log_section "Workflow Order (Next Steps)"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills"

    # Plan should NOT suggest implement (requires tasks)
    ((TESTS_RUN++))
    if grep -A20 "## Next Steps" "$base/iikit-03-plan/SKILL.md" | grep -E "^- /iikit-08-implement|^[0-9]\..*/iikit-08-implement" >/dev/null 2>&1; then
        log_fail "plan suggests implement before tasks"
    else
        log_pass "plan does not suggest implement"
    fi

    # Testify should NOT suggest analyze (requires tasks)
    ((TESTS_RUN++))
    if grep -A15 "## Next Steps" "$base/iikit-05-testify/SKILL.md" | grep -E "^- /iikit-07-analyze|^[0-9]\..*/iikit-07-analyze" >/dev/null 2>&1; then
        log_fail "testify suggests analyze before tasks"
    else
        log_pass "testify does not suggest analyze"
    fi

    # Checklist should NOT suggest implement
    ((TESTS_RUN++))
    if grep -A20 "## Next Steps" "$base/iikit-04-checklist/SKILL.md" | grep -E "^- /iikit-08-implement|^[0-9]\..*/iikit-08-implement" >/dev/null 2>&1; then
        log_fail "checklist suggests implement before tasks"
    else
        log_pass "checklist does not suggest implement"
    fi
}

test_tdd_check_has_args() {
    log_section "TDD Check Has Arguments"
    local impl=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-08-implement/SKILL.md"

    ((TESTS_RUN++))
    if grep -q 'testify-tdd.sh comprehensive-check "FEATURE_DIR' "$impl"; then
        log_pass "implement has complete testify-tdd.sh args"
    else
        log_fail "implement missing testify-tdd.sh args"
    fi
}

test_bash_prefix() {
    log_section "Scripts Use Bash Prefix"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills"

    # Check skills use "bash .tessl/..." not just ".tessl/..."
    ((TESTS_RUN++))
    local found_issue=false

    for skill in "$base"/iikit-*/SKILL.md; do
        # Look for script calls in bash blocks that don't have bash prefix
        if grep -B1 '\.tessl.*scripts/bash.*\.sh' "$skill" 2>/dev/null | grep -v 'bash \.' | grep -q '```bash'; then
            # Has a bash block with script call - check if it has bash prefix
            if grep -A1 '```bash' "$skill" | grep '\.tessl.*scripts/bash.*\.sh' | grep -v '^bash ' | grep -qv 'bash \.'; then
                found_issue=true
                log_fail "$(basename $(dirname $skill)) missing bash prefix"
            fi
        fi
    done

    if [[ "$found_issue" == "false" ]]; then
        log_pass "all scripts have bash prefix"
    fi
}

test_tdd_conditional_next_steps() {
    log_section "TDD Conditional Next Steps"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills"

    # Plan skill must show TDD as "REQUIRED by constitution" when mandatory
    ((TESTS_RUN++))
    if grep -q "REQUIRED by constitution.*test specifications\|REQUIRED by constitution) Generate test" "$base/iikit-03-plan/SKILL.md"; then
        log_pass "plan shows testify as REQUIRED when TDD mandatory"
    else
        log_fail "plan missing REQUIRED testify for mandatory TDD"
    fi

    # Plan skill must show TDD as "Optional" when not required
    ((TESTS_RUN++))
    if grep -q "(Optional).*test specifications for TDD\|(Optional) Generate test specifications" "$base/iikit-03-plan/SKILL.md"; then
        log_pass "plan shows testify as Optional when TDD not mandatory"
    else
        log_fail "plan missing Optional testify for non-mandatory TDD"
    fi

    # Checklist skill must include testify in next steps
    ((TESTS_RUN++))
    if grep -A20 "## Next Steps" "$base/iikit-04-checklist/SKILL.md" | grep -q "iikit-05-testify"; then
        log_pass "checklist includes testify in next steps"
    else
        log_fail "checklist missing testify in next steps"
    fi
}

test_testify_tdd_comprehensive_check() {
    log_section "TDD Script Comprehensive Check"
    local script=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh"

    # Test that comprehensive-check requires 4 arguments (command + 3 args)
    ((TESTS_RUN++))
    local output
    output=$(bash "$script" comprehensive-check 2>&1) || true
    if echo "$output" | grep -q "Usage.*comprehensive-check"; then
        log_pass "comprehensive-check shows correct usage"
    else
        log_fail "comprehensive-check usage message incorrect"
    fi

    # Test that comprehensive-check with only 2 args fails with usage message
    ((TESTS_RUN++))
    output=$(bash "$script" comprehensive-check "test.md" 2>&1) || true
    if echo "$output" | grep -q "Usage"; then
        log_pass "comprehensive-check rejects missing args"
    else
        log_fail "comprehensive-check accepted missing args (output: ${output:0:80})"
    fi

    # Test with all args (should not error on missing files, just return JSON)
    ((TESTS_RUN++))
    output=$(bash "$script" comprehensive-check "/nonexistent/test.md" "/nonexistent/context.json" "/nonexistent/constitution.md" 2>&1) || true
    if echo "$output" | grep -q '"overall_status"'; then
        log_pass "comprehensive-check returns JSON with all args"
    else
        log_fail "comprehensive-check failed with all args"
    fi
}

test_nested_git_repo() {
    log_section "Nested Git Repository Detection"
    # Store absolute path to script before changing directories
    local script="$TEST_DIR/.tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/create-new-feature.sh"

    # Create a nested git structure
    local parent_dir
    parent_dir=$(mktemp -d)

    # Create parent git repo
    cd "$parent_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "# Parent" > README.md
    git add README.md && git commit -qm "init parent"
    mkdir -p .specify specs

    # Create child project (subdirectory with its own .specify)
    mkdir -p child/.specify child/specs
    echo "# Child" > child/README.md

    # Test from child directory - should use child's .specify, not parent's
    cd "$parent_dir/child"

    ((TESTS_RUN++))
    # Run with --help to check script loads (doesn't actually create feature)
    local output
    output=$(bash "$script" --help 2>&1) || true
    if echo "$output" | grep -q "Usage\|OPTIONS\|DESCRIPTION"; then
        log_pass "create-new-feature.sh runs from nested project"
    else
        log_fail "create-new-feature.sh fails in nested project (output: ${output:0:80})"
    fi

    # Cleanup
    cd "$TEST_DIR"
    rm -rf "$parent_dir"
}

test_single_feature_fallback() {
    log_section "Single Feature Directory Fallback"
    local prereq_script=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh"

    # Setup: Create a feature directory but stay on main branch
    mkdir -p .specify specs/001-test-feature
    echo "# Test Constitution" > CONSTITUTION.md
    echo "## Core Principles" >> CONSTITUTION.md

    # Create minimal spec and plan
    cat > specs/001-test-feature/spec.md << 'SPEC'
# Test Feature
## Requirements
### Functional Requirements
- **FR-01**: Test requirement
## Success Criteria
- **SC-01**: Test criterion
## User Scenarios
### User Story
As a user, I want to test.
SPEC

    cat > specs/001-test-feature/plan.md << 'PLAN'
# Implementation Plan
## Technical Context
**Language/Version**: Bash
PLAN

    # We're on main branch, not 001-test-feature
    # Script should detect single feature and use it

    ((TESTS_RUN++))
    local output
    output=$(bash "$prereq_script" --paths-only 2>&1) || true
    if echo "$output" | grep -q "001-test-feature"; then
        log_pass "single feature fallback works on non-feature branch"
    else
        log_fail "single feature fallback failed (output: ${output:0:100}...)"
    fi
}

test_tdd_assessment() {
    log_section "TDD Assessment Logic"
    local script=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh"
    local tmp_constitution
    tmp_constitution=$(mktemp)

    # Test mandatory TDD detection (MUST...TDD pattern)
    ((TESTS_RUN++))
    echo "## Principles" > "$tmp_constitution"
    echo "- All code MUST use TDD methodology" >> "$tmp_constitution"
    local output
    output=$(bash "$script" get-tdd-determination "$tmp_constitution" 2>&1)
    if [[ "$output" == "mandatory" ]]; then
        log_pass "detects mandatory TDD (MUST...TDD)"
    else
        log_fail "failed to detect mandatory TDD (got: $output)"
    fi

    # Test mandatory TDD detection (test-first MUST pattern)
    ((TESTS_RUN++))
    echo "## Principles" > "$tmp_constitution"
    echo "- test-first MUST be used for all features" >> "$tmp_constitution"
    output=$(bash "$script" get-tdd-determination "$tmp_constitution" 2>&1)
    if [[ "$output" == "mandatory" ]]; then
        log_pass "detects mandatory TDD (test-first MUST)"
    else
        log_fail "failed to detect test-first MUST (got: $output)"
    fi

    # Test optional TDD (no TDD keywords)
    ((TESTS_RUN++))
    echo "## Principles" > "$tmp_constitution"
    echo "- Code MUST be well documented" >> "$tmp_constitution"
    output=$(bash "$script" get-tdd-determination "$tmp_constitution" 2>&1)
    if [[ "$output" == "optional" ]]; then
        log_pass "detects optional TDD (no indicators)"
    else
        log_fail "failed to detect optional TDD (got: $output)"
    fi

    # Test forbidden TDD detection
    ((TESTS_RUN++))
    echo "## Principles" > "$tmp_constitution"
    echo "- MUST use test-after approach only" >> "$tmp_constitution"
    output=$(bash "$script" get-tdd-determination "$tmp_constitution" 2>&1)
    if [[ "$output" == "forbidden" ]]; then
        log_pass "detects forbidden TDD"
    else
        log_fail "failed to detect forbidden TDD (got: $output)"
    fi

    rm -f "$tmp_constitution"
}

test_assertion_hash_integrity() {
    log_section "Assertion Hash Integrity"
    local script=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh"
    local tmp_test_specs
    local tmp_context
    tmp_test_specs=$(mktemp)
    tmp_context=$(mktemp)

    # Create test specs with assertions
    cat > "$tmp_test_specs" << 'EOF'
# Test Specifications
## Test Case 1
**Given**: A user is logged in
**When**: They click logout
**Then**: They are redirected to login page
EOF

    # Test hash computation is deterministic
    ((TESTS_RUN++))
    local hash1 hash2
    hash1=$(bash "$script" compute-hash "$tmp_test_specs" 2>&1)
    hash2=$(bash "$script" compute-hash "$tmp_test_specs" 2>&1)
    if [[ "$hash1" == "$hash2" && -n "$hash1" && "$hash1" != "NO_ASSERTIONS" ]]; then
        log_pass "hash computation is deterministic"
    else
        log_fail "hash not deterministic (h1: $hash1, h2: $hash2)"
    fi

    # Test store and verify cycle
    ((TESTS_RUN++))
    echo '{}' > "$tmp_context"
    bash "$script" store-hash "$tmp_test_specs" "$tmp_context" >/dev/null 2>&1
    local verify_result
    verify_result=$(bash "$script" verify-hash "$tmp_test_specs" "$tmp_context" 2>&1)
    if [[ "$verify_result" == "valid" ]]; then
        log_pass "store-hash and verify-hash work together"
    else
        log_fail "verify-hash failed after store (got: $verify_result)"
    fi

    # Test that modified assertions are detected
    ((TESTS_RUN++))
    echo "**Then**: They see an error message" >> "$tmp_test_specs"
    verify_result=$(bash "$script" verify-hash "$tmp_test_specs" "$tmp_context" 2>&1)
    if [[ "$verify_result" == "invalid" ]]; then
        log_pass "modified assertions detected as invalid"
    else
        log_fail "failed to detect modified assertions (got: $verify_result)"
    fi

    rm -f "$tmp_test_specs" "$tmp_context"
}

test_multiple_feature_warning() {
    log_section "Multiple Feature Directory Warning"
    local prereq_script=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh"

    # Create multiple feature directories
    mkdir -p specs/002-another-feature
    cat > specs/002-another-feature/spec.md << 'SPEC'
# Another Feature
## Requirements
### Functional Requirements
- **FR-01**: Another requirement
## Success Criteria
- **SC-01**: Another criterion
## User Scenarios
### User Story
As a user, I want another thing.
SPEC

    # We're on main branch with multiple features - should warn
    ((TESTS_RUN++))
    local output
    output=$(bash "$prereq_script" --paths-only 2>&1) || true
    if echo "$output" | grep -qi "WARNING\|multiple\|SPECIFY_FEATURE"; then
        log_pass "warns about multiple feature directories"
    else
        log_fail "no warning for multiple features (output: ${output:0:100}...)"
    fi

    # Clean up
    rm -rf specs/002-another-feature
}

test_feature_prefix_matching() {
    log_section "Feature Prefix Matching"
    local prereq_script=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh"

    # Create a feature with different branch name than directory
    # Branch: 001-fix-bug, Directory: 001-test-feature (already exists from earlier test)

    # Create and checkout a branch with same prefix but different name
    git checkout -qb 001-fix-bug 2>/dev/null || git checkout -q 001-fix-bug 2>/dev/null || {
        # If branch exists, just use it
        true
    }

    ((TESTS_RUN++))
    local output
    output=$(bash "$prereq_script" --paths-only 2>&1) || true
    # Should find 001-test-feature even though branch is 001-fix-bug
    if echo "$output" | grep -q "001-test-feature"; then
        log_pass "prefix matching finds correct feature directory"
    else
        log_fail "prefix matching failed (output: ${output:0:100}...)"
    fi

    # Return to main branch
    git checkout -q main 2>/dev/null || git checkout -q master 2>/dev/null || true
}

test_init_script() {
    log_section "Init Script"
    local script=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/init-project.sh"

    ((TESTS_RUN++))
    if [[ -f "$script" ]]; then
        local output
        output=$(bash "$script" --help 2>&1) || true
        if echo "$output" | grep -qi "usage\|help\|init"; then
            log_pass "init-project.sh runs with --help"
        else
            log_fail "init-project.sh --help failed"
        fi
    else
        log_pass "init-project.sh not present (optional)"
    fi
}

test_update_agent_context_script() {
    log_section "Update Agent Context Script"
    local script=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/update-agent-context.sh"

    ((TESTS_RUN++))
    if [[ -f "$script" ]]; then
        # This script doesn't have --help, but we can check it sources common.sh correctly
        local output
        output=$(bash -n "$script" 2>&1)
        if [[ $? -eq 0 ]]; then
            log_pass "update-agent-context.sh has valid syntax"
        else
            log_fail "update-agent-context.sh syntax error: $output"
        fi
    else
        log_fail "update-agent-context.sh not found"
    fi
}

test_template_paths_resolve() {
    log_section "Template Paths Resolve"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core"
    local scripts_dir="$base/scripts/bash"
    local templates_dir="$base/templates"

    # Verify templates directory exists
    ((TESTS_RUN++))
    if [[ -d "$templates_dir" ]]; then
        log_pass "templates directory exists"
    else
        log_fail "templates directory missing: $templates_dir"
        return
    fi

    # Check each script's template references resolve
    # create-new-feature.sh -> spec-template.md
    ((TESTS_RUN++))
    local script_dir="$scripts_dir"
    local template_path="$script_dir/../../templates/spec-template.md"
    if [[ -f "$template_path" ]]; then
        log_pass "create-new-feature.sh template path resolves"
    else
        log_fail "create-new-feature.sh template not found: $template_path"
    fi

    # setup-plan.sh -> plan-template.md
    ((TESTS_RUN++))
    template_path="$script_dir/../../templates/plan-template.md"
    if [[ -f "$template_path" ]]; then
        log_pass "setup-plan.sh template path resolves"
    else
        log_fail "setup-plan.sh template not found: $template_path"
    fi

    # update-agent-context.sh -> agent-file-template.md
    ((TESTS_RUN++))
    template_path="$script_dir/../../templates/agent-file-template.md"
    if [[ -f "$template_path" ]]; then
        log_pass "update-agent-context.sh template path resolves"
    else
        log_fail "update-agent-context.sh template not found: $template_path"
    fi

    # Verify all expected templates exist
    local expected_templates=(
        "spec-template.md"
        "plan-template.md"
        "tasks-template.md"
        "constitution-template.md"
        "checklist-template.md"
        "testspec-template.md"
        "agent-file-template.md"
    )

    for tmpl in "${expected_templates[@]}"; do
        ((TESTS_RUN++))
        if [[ -f "$templates_dir/$tmpl" ]]; then
            log_pass "template exists: $tmpl"
        else
            log_fail "template missing: $tmpl"
        fi
    done
}

test_skill_template_references() {
    log_section "Skill Template References"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills"

    # Check that skill files reference correct template paths
    # iikit-00-constitution should reference iikit-core/templates/
    ((TESTS_RUN++))
    if grep -q "iikit-core/templates/constitution-template.md" "$base/iikit-00-constitution/SKILL.md"; then
        log_pass "constitution skill references correct template path"
    else
        log_fail "constitution skill has wrong template path"
    fi

    # iikit-01-specify should reference iikit-core/templates/
    ((TESTS_RUN++))
    if grep -q "iikit-core/templates/spec-template.md" "$base/iikit-01-specify/SKILL.md"; then
        log_pass "specify skill references correct template path"
    else
        log_fail "specify skill has wrong template path"
    fi

    # Verify no skills reference old paths
    ((TESTS_RUN++))
    local old_path_count
    old_path_count=$(grep -r "intent-integrity-kit/templates/" "$base"/*/SKILL.md 2>/dev/null | grep -v "iikit-core/templates" | wc -l)
    if [[ "$old_path_count" -eq 0 ]]; then
        log_pass "no skills reference old template paths"
    else
        log_fail "found $old_path_count references to old template paths"
    fi

    # Verify no skills reference iikit-01-specify/templates (old location)
    ((TESTS_RUN++))
    if grep -rq "iikit-01-specify/templates/" "$base"/*/SKILL.md 2>/dev/null; then
        log_fail "found references to old iikit-01-specify/templates path"
    else
        log_pass "no references to old iikit-01-specify/templates path"
    fi
}

test_skill_script_references() {
    log_section "Skill Script References (Bash)"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills"

    # CRITICAL: Verify all SKILL.md files reference scripts at iikit-core/scripts/
    # This catches the bug where skills referenced iikit-01-specify/scripts/ instead

    # Check that script paths point to iikit-core, not individual skill directories
    ((TESTS_RUN++))
    local wrong_script_refs
    wrong_script_refs=$(grep -rh "iikit-0[0-9]-[a-z]*/scripts/" "$base"/*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$wrong_script_refs" -eq 0 ]]; then
        log_pass "no skills reference scripts in wrong skill directory"
    else
        log_fail "found $wrong_script_refs references to scripts in wrong directory (should be iikit-core/scripts/)"
        grep -rn "iikit-0[0-9]-[a-z]*/scripts/" "$base"/*/SKILL.md 2>/dev/null | head -5
    fi

    # Verify scripts are referenced at iikit-core/scripts/bash/
    ((TESTS_RUN++))
    local skills_with_script_refs=0
    local skills_with_correct_refs=0
    for skill in "$base"/iikit-*/SKILL.md; do
        if grep -q "scripts/bash/" "$skill" 2>/dev/null; then
            ((skills_with_script_refs++))
            if grep -q "iikit-core/scripts/bash/" "$skill" 2>/dev/null; then
                ((skills_with_correct_refs++))
            fi
        fi
    done
    if [[ "$skills_with_script_refs" -eq "$skills_with_correct_refs" ]]; then
        log_pass "all bash script references use iikit-core/scripts/bash/"
    else
        log_fail "bash script path mismatch: $skills_with_correct_refs/$skills_with_script_refs use correct path"
    fi

    # Check specific critical scripts are referenced correctly
    local critical_scripts=(
        "check-prerequisites.sh"
        "create-new-feature.sh"
        "setup-plan.sh"
        "testify-tdd.sh"
    )

    for script in "${critical_scripts[@]}"; do
        ((TESTS_RUN++))
        local wrong_refs
        wrong_refs=$(grep -rh "$script" "$base"/*/SKILL.md 2>/dev/null | grep -v "iikit-core/scripts" | grep "scripts/bash" | wc -l)
        if [[ "$wrong_refs" -eq 0 ]]; then
            log_pass "$script references are correct"
        else
            log_fail "$script has $wrong_refs wrong path references"
        fi
    done
}

test_powershell_script_references() {
    log_section "Skill Script References (PowerShell)"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills"

    # Check that PowerShell script paths point to iikit-core, not individual skill directories
    ((TESTS_RUN++))
    local wrong_ps_refs
    wrong_ps_refs=$(grep -rh "iikit-0[0-9]-[a-z]*/scripts/powershell" "$base"/*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$wrong_ps_refs" -eq 0 ]]; then
        log_pass "no skills reference PowerShell scripts in wrong directory"
    else
        log_fail "found $wrong_ps_refs PowerShell references in wrong directory"
        grep -rn "iikit-0[0-9]-[a-z]*/scripts/powershell" "$base"/*/SKILL.md 2>/dev/null | head -5
    fi

    # Verify PowerShell scripts are referenced at iikit-core/scripts/powershell/
    ((TESTS_RUN++))
    local skills_with_ps_refs=0
    local skills_with_correct_ps_refs=0
    for skill in "$base"/iikit-*/SKILL.md; do
        if grep -q "scripts/powershell/" "$skill" 2>/dev/null; then
            ((skills_with_ps_refs++))
            if grep -q "iikit-core/scripts/powershell/" "$skill" 2>/dev/null; then
                ((skills_with_correct_ps_refs++))
            fi
        fi
    done
    if [[ "$skills_with_ps_refs" -eq "$skills_with_correct_ps_refs" ]]; then
        log_pass "all PowerShell script references use iikit-core/scripts/powershell/"
    else
        log_fail "PowerShell path mismatch: $skills_with_correct_ps_refs/$skills_with_ps_refs use correct path"
    fi

    # Check specific critical PowerShell scripts are referenced correctly
    local critical_ps_scripts=(
        "check-prerequisites.ps1"
        "create-new-feature.ps1"
        "setup-plan.ps1"
        "testify-tdd.ps1"
    )

    for script in "${critical_ps_scripts[@]}"; do
        ((TESTS_RUN++))
        local wrong_refs
        wrong_refs=$(grep -rh "$script" "$base"/*/SKILL.md 2>/dev/null | grep -v "iikit-core/scripts" | grep "scripts/powershell" | wc -l)
        if [[ "$wrong_refs" -eq 0 ]]; then
            log_pass "$script references are correct"
        else
            log_fail "$script has $wrong_refs wrong path references"
        fi
    done
}

test_documentation_path_consistency() {
    log_section "Documentation Path Consistency"
    local tile_root=".tessl/tiles/tessl-labs/intent-integrity-kit"

    # Check that documented paths actually exist
    # Extract paths from SKILL.md files and verify they resolve

    # Test 1: All referenced .sh scripts should exist
    ((TESTS_RUN++))
    local missing_scripts=0
    while IFS= read -r script_ref; do
        # Extract the path after .tessl/tiles/tessl-labs/intent-integrity-kit/
        local rel_path
        rel_path=$(echo "$script_ref" | grep -oE 'skills/[^"'"'"' ]+\.sh' | head -1)
        if [[ -n "$rel_path" && ! -f "$tile_root/$rel_path" ]]; then
            ((missing_scripts++))
            log_info "Missing script: $rel_path"
        fi
    done < <(grep -rh "\.tessl.*\.sh" "$tile_root/skills"/*/SKILL.md 2>/dev/null)

    if [[ "$missing_scripts" -eq 0 ]]; then
        log_pass "all referenced scripts exist"
    else
        log_fail "$missing_scripts referenced scripts are missing"
    fi

    # Test 2: All referenced .md templates should exist
    ((TESTS_RUN++))
    local missing_templates=0
    while IFS= read -r template_ref; do
        local rel_path
        rel_path=$(echo "$template_ref" | grep -oE 'skills/[^"'"'"' ]+\.md' | head -1)
        if [[ -n "$rel_path" && "$rel_path" == *"templates/"* && ! -f "$tile_root/$rel_path" ]]; then
            ((missing_templates++))
            log_info "Missing template: $rel_path"
        fi
    done < <(grep -rh "\.tessl.*templates.*\.md" "$tile_root/skills"/*/SKILL.md 2>/dev/null)

    if [[ "$missing_templates" -eq 0 ]]; then
        log_pass "all referenced templates exist"
    else
        log_fail "$missing_templates referenced templates are missing"
    fi

    # Test 3: No references to .specify/scripts/ (old location)
    ((TESTS_RUN++))
    if grep -rq "\.specify/scripts/" "$tile_root/skills"/*/SKILL.md 2>/dev/null; then
        log_fail "found references to old .specify/scripts/ location"
        grep -rn "\.specify/scripts/" "$tile_root/skills"/*/SKILL.md 2>/dev/null | head -3
    else
        log_pass "no references to old .specify/scripts/ location"
    fi

    # Test 4: No references to .specify/templates/ (old location)
    ((TESTS_RUN++))
    if grep -rq "\.specify/templates/" "$tile_root/skills"/*/SKILL.md 2>/dev/null; then
        log_fail "found references to old .specify/templates/ location"
    else
        log_pass "no references to old .specify/templates/ location"
    fi
}

test_readme_path_consistency() {
    log_section "README/Doc Path Consistency"
    local tile_root=".tessl/tiles/tessl-labs/intent-integrity-kit"

    # Check index.md and any README files for path consistency
    local doc_files=("$tile_root/index.md")
    [[ -f "$tile_root/README.md" ]] && doc_files+=("$tile_root/README.md")

    for doc in "${doc_files[@]}"; do
        [[ ! -f "$doc" ]] && continue

        # Test: No references to .specify/scripts/
        ((TESTS_RUN++))
        if grep -q "\.specify/scripts/" "$doc" 2>/dev/null; then
            log_fail "$(basename $doc) references old .specify/scripts/ path"
        else
            log_pass "$(basename $doc) has no old .specify/scripts/ references"
        fi

        # Test: No references to .specify/templates/
        ((TESTS_RUN++))
        if grep -q "\.specify/templates/" "$doc" 2>/dev/null; then
            log_fail "$(basename $doc) references old .specify/templates/ path"
        else
            log_pass "$(basename $doc) has no old .specify/templates/ references"
        fi
    done
}

test_bash_script_inner_template_refs() {
    log_section "Bash Script Inner Template References"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash"
    local templates_dir=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/templates"

    # Scripts that reference templates - verify they use relative ../../templates/ path
    local scripts_with_templates=(
        "create-new-feature.sh:spec-template.md"
        "setup-plan.sh:plan-template.md"
        "update-agent-context.sh:agent-file-template.md"
    )

    for entry in "${scripts_with_templates[@]}"; do
        local script="${entry%%:*}"
        local template="${entry##*:}"
        ((TESTS_RUN++))

        if [[ ! -f "$base/$script" ]]; then
            log_fail "bash script not found: $script"
            continue
        fi

        # Check that script references the template via relative path
        if grep -q '../../templates/'"$template" "$base/$script" 2>/dev/null; then
            log_pass "$script references $template correctly"
        else
            log_fail "$script doesn't use relative ../../templates/$template path"
        fi

        # Verify the referenced template exists
        ((TESTS_RUN++))
        if [[ -f "$templates_dir/$template" ]]; then
            log_pass "$template exists for $script"
        else
            log_fail "$template missing (referenced by $script)"
        fi
    done

    # No deprecated .specify/templates/ references in bash scripts
    ((TESTS_RUN++))
    if grep -rq "\.specify/templates/" "$base"/*.sh 2>/dev/null; then
        log_fail "bash scripts reference deprecated .specify/templates/"
    else
        log_pass "no bash scripts reference deprecated .specify/templates/"
    fi
}

test_powershell_script_inner_template_refs() {
    log_section "PowerShell Script Inner Template References"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell"
    local templates_dir=".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/templates"

    # Scripts that reference templates
    local scripts_with_templates=(
        "create-new-feature.ps1:spec-template.md"
        "setup-plan.ps1:plan-template.md"
        "update-agent-context.ps1:agent-file-template.md"
    )

    for entry in "${scripts_with_templates[@]}"; do
        local script="${entry%%:*}"
        local template="${entry##*:}"
        ((TESTS_RUN++))

        if [[ ! -f "$base/$script" ]]; then
            log_warn "powershell script not found: $script (tessl registry strips .ps1)"
            continue
        fi

        # Check that script references the template via relative path (PowerShell uses backslashes)
        if grep -qE '\.\.\\\.\.\\templates\\'"$template|"'\.\.\/\.\.\/templates\/'"$template" "$base/$script" 2>/dev/null; then
            log_pass "$script references $template correctly"
        else
            log_fail "$script doesn't use relative ..\\..\\templates\\$template path"
        fi

        # Verify the referenced template exists
        ((TESTS_RUN++))
        if [[ -f "$templates_dir/$template" ]]; then
            log_pass "$template exists for $script"
        else
            log_fail "$template missing (referenced by $script)"
        fi
    done

    # No deprecated .specify/templates/ references in PowerShell scripts
    ((TESTS_RUN++))
    if grep -rq "\.specify[/\\]templates" "$base"/*.ps1 2>/dev/null; then
        log_fail "powershell scripts reference deprecated .specify/templates/"
    else
        log_pass "no powershell scripts reference deprecated .specify/templates/"
    fi
}

test_all_skill_template_refs() {
    log_section "All SKILL.md Template References"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills"

    # All template references should use iikit-core/templates/
    ((TESTS_RUN++))
    local wrong_template_refs
    wrong_template_refs=$(grep -rh "iikit-0[0-9]-[a-z]*/templates/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$wrong_template_refs" -eq 0 ]]; then
        log_pass "no skills reference templates in wrong directory"
    else
        log_fail "found $wrong_template_refs wrong template path references"
        grep -rn "iikit-0[0-9]-[a-z]*/templates/" "$base"/iikit-*/SKILL.md 2>/dev/null | head -5
    fi

    # Count correct template references
    ((TESTS_RUN++))
    local correct_refs
    correct_refs=$(grep -rh "iikit-core/templates/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$correct_refs" -gt 0 ]]; then
        log_pass "skills use iikit-core/templates/ ($correct_refs refs)"
    else
        log_warn "no template references found in skills (may be OK)"
    fi
}

test_skill_numbering_consistency() {
    log_section "Skill Numbering Consistency"
    local base=".tessl/tiles/tessl-labs/intent-integrity-kit/skills"

    # Verify skill directories match expected numbering
    local expected_skills=(
        "iikit-00-constitution"
        "iikit-01-specify"
        "iikit-02-clarify"
        "iikit-03-plan"
        "iikit-04-checklist"
        "iikit-05-testify"
        "iikit-06-tasks"
        "iikit-07-analyze"
        "iikit-08-implement"
        "iikit-09-taskstoissues"
    )

    for skill in "${expected_skills[@]}"; do
        ((TESTS_RUN++))
        if [[ -d "$base/$skill" ]]; then
            log_pass "skill directory exists: $skill"
        else
            log_fail "skill directory missing: $skill"
        fi
    done

    # Verify SKILL.md "Next Steps" sections reference correct skill numbers
    # E.g., iikit-03-plan should suggest iikit-06-tasks, not iikit-05-tasks
    ((TESTS_RUN++))
    local wrong_numbering=0

    # Plan (03) should NOT suggest implement (08) directly
    if grep -A20 "## Next Steps" "$base/iikit-03-plan/SKILL.md" 2>/dev/null | grep -qE "/iikit-08-implement[^-]"; then
        # Check if it's in a conditional block (OK) or direct suggestion (BAD)
        if grep -A20 "## Next Steps" "$base/iikit-03-plan/SKILL.md" 2>/dev/null | grep -B2 "/iikit-08-implement" | grep -qiE "if|when|after|require"; then
            : # Conditional reference is OK
        else
            ((wrong_numbering++))
            log_info "plan directly suggests implement"
        fi
    fi

    # Tasks (06) should suggest analyze (07) and implement (08)
    if ! grep -A15 "## Next Steps" "$base/iikit-06-tasks/SKILL.md" 2>/dev/null | grep -q "/iikit-07-analyze"; then
        ((wrong_numbering++))
        log_info "tasks doesn't suggest analyze (07)"
    fi

    if [[ "$wrong_numbering" -eq 0 ]]; then
        log_pass "skill numbering in next steps is consistent"
    else
        log_fail "found $wrong_numbering skill numbering issues in next steps"
    fi
}

main() {
    ORIGINAL_DIR=$(pwd)

    while [[ $# -gt 0 ]]; do
        case $1 in
            --from-local) TILE_SOURCE="local"; shift ;;
            --from-registry) TILE_SOURCE="registry"; shift ;;
            *) echo "Unknown: $1"; exit 1 ;;
        esac
    done

    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  Intent Integrity Kit Tile Integration Tests   ║"
    echo "╚══════════════════════════════════════════════════╝"

    trap teardown EXIT

    setup
    test_scripts_exist
    test_powershell_scripts_exist
    test_scripts_executable
    test_templates_exist
    test_skills_exist
    test_workflow_order
    test_tdd_check_has_args
    test_bash_prefix
    test_tdd_conditional_next_steps
    test_testify_tdd_comprehensive_check
    test_nested_git_repo
    test_single_feature_fallback
    test_tdd_assessment
    test_assertion_hash_integrity
    test_multiple_feature_warning
    test_feature_prefix_matching
    test_init_script
    test_update_agent_context_script
    test_template_paths_resolve
    test_skill_template_references
    test_skill_script_references
    test_powershell_script_references
    test_bash_script_inner_template_refs
    test_powershell_script_inner_template_refs
    test_all_skill_template_refs
    test_documentation_path_consistency
    test_readme_path_consistency
    test_skill_numbering_consistency

    log_section "Summary"
    echo "  Total:   $TESTS_RUN"
    echo -e "  ${GREEN}Passed:  $TESTS_PASSED${NC}"
    echo -e "  ${YELLOW}Warned:  $TESTS_WARNED${NC}"
    echo -e "  ${RED}Failed:  $TESTS_FAILED${NC}"

    [[ $TESTS_FAILED -gt 0 ]] && exit 1
    exit 0
}

main "$@"
