#!/usr/bin/env bash
#
# Intent Integrity Kit Source Validation Tests
#
# Tests the source repository for documentation and skill consistency.
# Single source of truth: .claude/skills/
# tiles/intent-integrity-kit/skills is a symlink to .claude/skills/.
#
# Usage:
#   ./tests/run-source-tests.sh
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

# Find repo root (tests/ is at repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)); }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

cd "$REPO_ROOT"

# The single source of truth for skills
SKILLS_DIR=".claude/skills"

# ─── Symlink Structure ───────────────────────────────────────────────────────

test_symlink_structure() {
    log_section "Symlink Structure"

    # .claude/skills must be a real directory (source of truth)
    ((TESTS_RUN++))
    if [[ -d ".claude/skills" && ! -L ".claude/skills" ]]; then
        log_pass ".claude/skills is a real directory (source of truth)"
    else
        log_fail ".claude/skills should be a real directory, not a symlink"
    fi

    # tiles/intent-integrity-kit/skills must be a symlink to .claude/skills
    ((TESTS_RUN++))
    if [[ -L "tiles/intent-integrity-kit/skills" ]]; then
        local target
        target=$(readlink tiles/intent-integrity-kit/skills)
        if [[ "$target" == *".claude/skills"* ]]; then
            log_pass "tiles/intent-integrity-kit/skills symlinks to .claude/skills ($target)"
        else
            log_fail "tiles/intent-integrity-kit/skills symlinks to wrong target: $target"
        fi
    else
        log_fail "tiles/intent-integrity-kit/skills is not a symlink"
    fi

    # .tessl/tiles/tessl-labs/intent-integrity-kit must be a symlink to the tile
    ((TESTS_RUN++))
    if [[ -L ".tessl/tiles/tessl-labs/intent-integrity-kit" ]]; then
        log_pass ".tessl/tiles/tessl-labs/intent-integrity-kit is a symlink"
    else
        log_fail ".tessl/tiles/tessl-labs/intent-integrity-kit is not a symlink"
    fi

    # .codex/skills, .gemini/skills, .opencode/skills should chain through .claude/skills
    for agent in .codex .gemini .opencode; do
        ((TESTS_RUN++))
        if [[ -L "$agent/skills" ]]; then
            log_pass "$agent/skills is a symlink"
        else
            log_fail "$agent/skills is not a symlink"
        fi
    done

    # .tessl path should resolve to the tile scripts
    ((TESTS_RUN++))
    if [[ -f ".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh" ]]; then
        log_pass ".tessl path resolves to tile scripts"
    else
        log_fail ".tessl path does not resolve to tile scripts"
    fi
}

# ─── Skill Completeness ─────────────────────────────────────────────────────

test_skill_completeness() {
    log_section "Skill Completeness"

    local expected=(
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
        "iikit-core"
    )

    for skill in "${expected[@]}"; do
        ((TESTS_RUN++))
        if [[ -d "$SKILLS_DIR/$skill" && -f "$SKILLS_DIR/$skill/SKILL.md" ]]; then
            log_pass "skill exists: $skill"
        else
            log_fail "skill missing: $skill"
        fi
    done
}

# ─── Script Path Consistency ─────────────────────────────────────────────────

test_script_paths() {
    log_section "Script Paths in SKILL.md (must use .tessl/tiles/...)"

    # All bash command paths must use .tessl/tiles/tessl-labs/intent-integrity-kit/skills/
    ((TESTS_RUN++))
    local correct_bash
    correct_bash=$(grep -rh "bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/" "$SKILLS_DIR"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    correct_bash="${correct_bash//[^0-9]/}"
    if [[ "$correct_bash" -gt 0 ]]; then
        log_pass "bash commands use .tessl/tiles/... path ($correct_bash refs)"
    else
        log_fail "no bash commands use .tessl/tiles/... path"
    fi

    # No .claude/skills/ paths should remain in SKILL.md files
    ((TESTS_RUN++))
    local wrong_paths
    wrong_paths=$(grep -rch "\.claude/skills/" "$SKILLS_DIR"/iikit-*/SKILL.md 2>/dev/null | awk '{s+=$1}END{print s+0}')
    if [[ "$wrong_paths" -eq 0 ]]; then
        log_pass "no .claude/skills/ paths in SKILL.md files"
    else
        log_fail "found $wrong_paths .claude/skills/ references in SKILL.md files"
        grep -rn "\.claude/skills/" "$SKILLS_DIR"/iikit-*/SKILL.md 2>/dev/null | head -5
    fi

    # PowerShell commands should use .tessl/tiles/ path
    ((TESTS_RUN++))
    local correct_pwsh
    correct_pwsh=$(grep -rh "pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/" "$SKILLS_DIR"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    correct_pwsh="${correct_pwsh//[^0-9]/}"
    if [[ "$correct_pwsh" -gt 0 ]]; then
        log_pass "pwsh commands use .tessl/tiles/... path ($correct_pwsh refs)"
    else
        log_warn "no pwsh commands found (may be OK)"
    fi

    # No deprecated .specify/scripts/ references
    ((TESTS_RUN++))
    if grep -rq "\.specify/scripts/" "$SKILLS_DIR"/iikit-*/SKILL.md 2>/dev/null; then
        log_fail "SKILL.md files reference deprecated .specify/scripts/"
    else
        log_pass "no deprecated .specify/scripts/ references"
    fi
}

# ─── Scripts and Templates Exist ─────────────────────────────────────────────

test_scripts_exist() {
    log_section "Scripts Exist"

    local bash_base="$SKILLS_DIR/iikit-core/scripts/bash"
    local bash_scripts=(
        "check-prerequisites.sh"
        "create-new-feature.sh"
        "setup-plan.sh"
        "testify-tdd.sh"
        "common.sh"
        "update-agent-context.sh"
    )

    for script in "${bash_scripts[@]}"; do
        ((TESTS_RUN++))
        if [[ -f "$bash_base/$script" ]]; then
            log_pass "bash: $script"
        else
            log_fail "bash missing: $script"
        fi
    done

    local ps_base="$SKILLS_DIR/iikit-core/scripts/powershell"
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
            log_pass "pwsh: $script"
        else
            log_fail "pwsh missing: $script"
        fi
    done
}

test_templates_exist() {
    log_section "Templates Exist"
    local base="$SKILLS_DIR/iikit-core/templates"

    local templates=(
        "constitution-template.md"
        "premise-template.md"
        "spec-template.md"
        "plan-template.md"
        "tasks-template.md"
        "checklist-template.md"
        "testspec-template.md"
        "agent-file-template.md"
        "prd-issue-template.md"
    )

    for template in "${templates[@]}"; do
        ((TESTS_RUN++))
        if [[ -f "$base/$template" ]]; then
            log_pass "template: $template"
        else
            log_fail "template missing: $template"
        fi
    done
}

# ─── Parallel Execution Feature ──────────────────────────────────────────────

test_parallel_execution() {
    log_section "Parallel Execution Feature"
    local impl="$SKILLS_DIR/iikit-08-implement/SKILL.md"
    local ref="$SKILLS_DIR/iikit-08-implement/references/parallel-execution.md"
    local tasks="$SKILLS_DIR/iikit-06-tasks/SKILL.md"

    # parallel-execution.md reference doc exists
    ((TESTS_RUN++))
    if [[ -f "$ref" ]]; then
        log_pass "references/parallel-execution.md exists"
    else
        log_fail "references/parallel-execution.md missing"
        return
    fi

    # SKILL.md links to parallel-execution.md
    ((TESTS_RUN++))
    if grep -q 'parallel-execution.md' "$impl"; then
        log_pass "implement SKILL.md references parallel-execution.md"
    else
        log_fail "implement SKILL.md does not reference parallel-execution.md"
    fi

    # Section 5 has subsections 5.1-5.5 (bold-formatted in SKILL.md)
    local subsections=("5.1 Task extraction" "5.2 Execution strategy" "5.3 Phase-by-phase" "5.4 Rules" "5.5 Failure handling")
    for sub in "${subsections[@]}"; do
        ((TESTS_RUN++))
        if grep -q "$sub" "$impl"; then
            log_pass "Section $sub present"
        else
            log_fail "Section $sub missing from implement SKILL.md"
        fi
    done

    # Execution mode report references formatting-guide.md
    ((TESTS_RUN++))
    if grep -q 'formatting-guide.md.*Execution Mode' "$impl"; then
        log_pass "execution mode report references formatting guide"
    else
        log_fail "execution mode report missing formatting guide reference"
    fi

    # Error handling table has parallel/task failure row
    ((TESTS_RUN++))
    if grep -qi 'task.*parallel.*failure\|parallel.*failure' "$impl"; then
        log_pass "error handling table has parallel task failure row"
    else
        log_fail "error handling table missing parallel task failure row"
    fi

    # Constitutional violation in parallel context documented
    ((TESTS_RUN++))
    if grep -qi 'constitutional violation.*worker' "$impl"; then
        log_pass "constitutional violation in parallel context documented"
    else
        log_fail "constitutional violation in parallel context not documented"
    fi

    # Batch/progress reporting documented
    ((TESTS_RUN++))
    if grep -qi 'report after each task/batch\|batch.*complete' "$impl"; then
        log_pass "batch completion reporting present"
    else
        log_fail "batch completion reporting missing"
    fi

    # ── Reference doc sections ──

    local ref_sections=(
        "Capability Detection"
        "Orchestrator/Worker Model"
        "Subagent Context Construction"
        "Within-Phase Protocol"
        "Cross-Story Protocol"
        "File Conflict Detection"
        "TDD in Parallel Context"
        "Tessl in Parallel Context"
    )
    for section in "${ref_sections[@]}"; do
        ((TESTS_RUN++))
        if grep -q "## $section" "$ref"; then
            log_pass "reference: $section section present"
        else
            log_fail "reference: $section section missing"
        fi
    done

    # Key protocol rules in reference doc
    ((TESTS_RUN++))
    if grep -q 'Do NOT write to tasks.md' "$ref"; then
        log_pass "worker responsibility: no tasks.md writes"
    else
        log_fail "worker responsibility: no tasks.md writes rule missing"
    fi

    ((TESTS_RUN++))
    if grep -q 'constitutional rules before every file write' "$ref"; then
        log_pass "worker responsibility: constitutional check"
    else
        log_fail "worker responsibility: constitutional check rule missing"
    fi

    ((TESTS_RUN++))
    if grep -q 'Dispatch priority' "$ref"; then
        log_pass "dispatch priority rule present"
    else
        log_fail "dispatch priority rule missing"
    fi

    ((TESTS_RUN++))
    if grep -q 'task ID as tiebreaker' "$ref"; then
        log_pass "sibling ordering tiebreaker defined"
    else
        log_fail "sibling ordering tiebreaker missing"
    fi

    ((TESTS_RUN++))
    if grep -q 'If eligibility fails' "$ref"; then
        log_pass "cross-story fallback clause present"
    else
        log_fail "cross-story fallback clause missing"
    fi

    ((TESTS_RUN++))
    if grep -q 'RED-phase batches' "$ref"; then
        log_pass "TDD RED-phase exception documented"
    else
        log_fail "TDD RED-phase exception missing"
    fi

    ((TESTS_RUN++))
    if grep -q 'zero tasks.*immediately complete' "$ref"; then
        log_pass "empty phase handling documented"
    else
        log_fail "empty phase handling missing"
    fi

    ((TESTS_RUN++))
    if grep -q 'Workstream failure' "$ref"; then
        log_pass "cross-story workstream failure handling present"
    else
        log_fail "cross-story workstream failure handling missing"
    fi

    ((TESTS_RUN++))
    if grep -q 'Pre-dispatch.*best-effort' "$ref"; then
        log_pass "pre-dispatch file conflict check documented"
    else
        log_fail "pre-dispatch file conflict check missing"
    fi

    ((TESTS_RUN++))
    if grep -q 'exclude the conflicting tasks from the batch' "$ref"; then
        log_pass "pre-dispatch conflict action specified"
    else
        log_fail "pre-dispatch conflict action not specified"
    fi

    ((TESTS_RUN++))
    if grep -q 'Leave conflicting tasks unmarked' "$ref"; then
        log_pass "post-conflict checkpoint rules specified"
    else
        log_fail "post-conflict checkpoint rules not specified"
    fi

    # ── Tasks skill parallel batch listing ──

    ((TESTS_RUN++))
    if grep -qi 'parallel batches\|list parallel batches' "$tasks"; then
        log_pass "tasks skill: parallel batch listing in critical path analysis"
    else
        log_fail "tasks skill: parallel batch listing missing"
    fi
}

# ─── PREMISE.md Support ──────────────────────────────────────────────────────

test_premise_support() {
    log_section "PREMISE.md Support"

    # premise-template.md exists
    ((TESTS_RUN++))
    if [[ -f "$SKILLS_DIR/iikit-core/templates/premise-template.md" ]]; then
        log_pass "premise-template.md exists"
    else
        log_fail "premise-template.md missing"
    fi

    # constitution skill references premise-template.md
    ((TESTS_RUN++))
    if grep -q 'premise-template.md' "$SKILLS_DIR/iikit-00-constitution/SKILL.md"; then
        log_pass "constitution skill references premise template"
    else
        log_fail "constitution skill does not reference premise template"
    fi

    # constitution-loading.md mentions premise
    ((TESTS_RUN++))
    if grep -qi 'premise' "$SKILLS_DIR/iikit-core/references/constitution-loading.md"; then
        log_pass "constitution-loading.md includes premise loading"
    else
        log_fail "constitution-loading.md missing premise loading"
    fi

    # check-prerequisites.sh detects PREMISE.md
    ((TESTS_RUN++))
    if grep -q 'PREMISE.md' "$SKILLS_DIR/iikit-core/scripts/bash/check-prerequisites.sh"; then
        log_pass "check-prerequisites.sh detects PREMISE.md"
    else
        log_fail "check-prerequisites.sh does not detect PREMISE.md"
    fi

    # git-setup.sh detects PREMISE.md
    ((TESTS_RUN++))
    if grep -q 'PREMISE.md' "$SKILLS_DIR/iikit-core/scripts/bash/git-setup.sh"; then
        log_pass "git-setup.sh detects PREMISE.md"
    else
        log_fail "git-setup.sh does not detect PREMISE.md"
    fi

    # init skill drafts PREMISE.md from PRD
    ((TESTS_RUN++))
    if grep -q 'Draft PREMISE.md' "$SKILLS_DIR/iikit-core/SKILL.md"; then
        log_pass "init skill drafts PREMISE.md from PRD"
    else
        log_fail "init skill does not draft PREMISE.md from PRD"
    fi

    # AGENTS.md documents PREMISE.md
    ((TESTS_RUN++))
    if grep -q 'PREMISE.md' "AGENTS.md"; then
        log_pass "AGENTS.md documents PREMISE.md"
    else
        log_fail "AGENTS.md does not document PREMISE.md"
    fi

    # prepare-tile.sh cleans premise-template.md
    ((TESTS_RUN++))
    if grep -q 'premise-template.md' "tests/prepare-tile.sh"; then
        log_pass "prepare-tile.sh includes premise-template.md in cleanup"
    else
        log_fail "prepare-tile.sh missing premise-template.md in cleanup"
    fi
}

# ─── Task Commits ────────────────────────────────────────────────────────────

test_task_commits() {
    log_section "Task Commits (§5.6)"
    local impl="$SKILLS_DIR/iikit-08-implement/SKILL.md"
    local ref="$SKILLS_DIR/iikit-08-implement/references/parallel-execution.md"

    # Section 5.6 exists in implement skill
    ((TESTS_RUN++))
    if grep -q '5.6 Task Commits' "$impl"; then
        log_pass "section 5.6 Task Commits present"
    else
        log_fail "section 5.6 Task Commits missing"
    fi

    # Commit message format specified
    ((TESTS_RUN++))
    if grep -q 'feat(<feature-id>)' "$impl"; then
        log_pass "commit message format specified"
    else
        log_fail "commit message format missing"
    fi

    # Bugfix prefix documented
    ((TESTS_RUN++))
    if grep -q 'fix(.*T-B' "$impl"; then
        log_pass "bugfix commit prefix documented"
    else
        log_fail "bugfix commit prefix not documented"
    fi

    # parallel-execution.md references §5.6
    ((TESTS_RUN++))
    if grep -q '§5.6' "$ref"; then
        log_pass "parallel-execution.md references §5.6"
    else
        log_fail "parallel-execution.md does not reference §5.6"
    fi

    # Next Steps says "Push commits" not "Commit and push"
    ((TESTS_RUN++))
    if grep -q 'Push commits' "$impl" && ! grep -q 'Commit and push' "$impl"; then
        log_pass "Next Steps: Push commits (not Commit and push)"
    else
        log_fail "Next Steps still says Commit and push"
    fi
}

# ─── GitHub API Fallback ────────────────────────────────────────────────────

test_github_fallback() {
    log_section "GitHub API Fallback (no gh hard dependency)"

    # implement skill: uses Fixes #N for closing
    ((TESTS_RUN++))
    if grep -q 'Fixes #' "$SKILLS_DIR/iikit-08-implement/SKILL.md"; then
        log_pass "implement: closes issues via Fixes #N in commit"
    else
        log_fail "implement: missing Fixes #N commit pattern"
    fi

    # implement skill: curl fallback for comments
    ((TESTS_RUN++))
    if grep -q 'curl.*GitHub API\|curl.*github' "$SKILLS_DIR/iikit-08-implement/SKILL.md"; then
        log_pass "implement: curl fallback for GitHub comments"
    else
        log_fail "implement: no curl fallback for GitHub comments"
    fi

    # bugfix skill: curl fallback for issue operations
    ((TESTS_RUN++))
    if grep -q 'curl.*GitHub API\|curl.*github' "$SKILLS_DIR/iikit-bugfix/SKILL.md"; then
        log_pass "bugfix: curl fallback for GitHub operations"
    else
        log_fail "bugfix: no curl fallback for GitHub operations"
    fi

    # taskstoissues: curl fallback
    ((TESTS_RUN++))
    if grep -q 'curl.*GitHub API\|curl.*github' "$SKILLS_DIR/iikit-09-taskstoissues/SKILL.md"; then
        log_pass "taskstoissues: curl fallback for issue creation"
    else
        log_fail "taskstoissues: no curl fallback for issue creation"
    fi

    # No skill should skip GitHub operations just because gh is missing
    ((TESTS_RUN++))
    local skip_gh_count
    skip_gh_count=$(grep -rl 'gh.*unavailable.*skip\|skip.*gh.*unavail\|If.*gh.*CLI.*unavailable.*skip' "$SKILLS_DIR"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    skip_gh_count="${skip_gh_count//[^0-9]/}"
    if [[ "$skip_gh_count" -eq 0 ]]; then
        log_pass "no skills skip GitHub operations due to missing gh"
    else
        log_fail "$skip_gh_count skill(s) still skip operations when gh missing"
        grep -rl 'gh.*unavailable.*skip\|skip.*gh.*unavail\|If.*gh.*CLI.*unavailable.*skip' "$SKILLS_DIR"/iikit-*/SKILL.md 2>/dev/null
    fi
}

# ─── Clarify No Question Limit ──────────────────────────────────────────────

test_clarify_no_limit() {
    log_section "Clarify: No Artificial Question Limit"
    local clarify="$SKILLS_DIR/iikit-02-clarify/SKILL.md"

    # No "max 5" or "5 questions" in clarify skill
    ((TESTS_RUN++))
    if grep -qi 'max 5\|5 question\|never exceed 5' "$clarify"; then
        log_fail "clarify skill still has 5-question limit"
    else
        log_pass "clarify skill has no artificial question limit"
    fi

    # Stop condition is ambiguity-driven, not count-driven
    ((TESTS_RUN++))
    if grep -q 'all critical ambiguities resolved' "$clarify"; then
        log_pass "clarify stop condition: ambiguity-driven"
    else
        log_fail "clarify stop condition: not ambiguity-driven"
    fi
}

# ─── Documentation Consistency ───────────────────────────────────────────────

test_documentation() {
    log_section "Documentation Consistency"

    local doc_files=(
        "README.md"
        "CLAUDE.md"
        "FRAMEWORK-PRINCIPLES.md"
    )

    for doc in "${doc_files[@]}"; do
        [[ ! -f "$doc" ]] && continue

        ((TESTS_RUN++))
        if grep -q "\.specify/scripts/" "$doc" 2>/dev/null; then
            log_fail "$doc references deprecated .specify/scripts/"
        else
            log_pass "$doc: no deprecated paths"
        fi
    done
}

# ─── tile.json Consistency ───────────────────────────────────────────────────

test_tile_json() {
    log_section "tile.json Consistency"
    local tile_json="tiles/intent-integrity-kit/tile.json"

    ((TESTS_RUN++))
    if [[ -f "$tile_json" ]]; then
        log_pass "tile.json exists"
    else
        log_fail "tile.json missing"
        return
    fi

    # All skills listed in tile.json should exist on disk
    local skill_names
    skill_names=$(grep '"path"' "$tile_json" | sed 's/.*"skills\/\(iikit-[^/]*\)\/.*/\1/')
    for skill in $skill_names; do
        ((TESTS_RUN++))
        if [[ -d "$SKILLS_DIR/$skill" ]]; then
            log_pass "tile.json skill on disk: $skill"
        else
            log_fail "tile.json lists $skill but directory missing"
        fi
    done
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  Intent Integrity Kit Source Validation Tests ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    log_info "Repo root: $REPO_ROOT"
    log_info "Skills dir: $SKILLS_DIR"

    test_symlink_structure
    test_skill_completeness
    test_script_paths
    test_scripts_exist
    test_templates_exist
    test_parallel_execution
    test_premise_support
    test_task_commits
    test_github_fallback
    test_clarify_no_limit
    test_documentation
    test_tile_json

    log_section "Summary"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"

    [[ $TESTS_FAILED -gt 0 ]] && exit 1
    exit 0
}

main "$@"
