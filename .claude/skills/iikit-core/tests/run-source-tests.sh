#!/usr/bin/env bash
#
# Intent Integrity Kit Source Validation Tests
#
# Tests the source repository for documentation consistency BEFORE publishing.
# Run this during development to catch path errors, stale documentation, etc.
#
# Usage:
#   ./run-source-tests.sh
#
# This complements run-tile-tests.sh which tests AFTER Tessl installation.

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

# Find repo root (where .claude/skills exists)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)); }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

cd "$REPO_ROOT"

test_local_skills_script_paths() {
    log_section "Local Skills Script Paths (.claude/skills/)"
    local base=".claude/skills"

    # All SKILL.md files should reference scripts at iikit-core/scripts/
    ((TESTS_RUN++))
    local wrong_refs
    wrong_refs=$(grep -rh "iikit-0[0-9]-[a-z]*/scripts/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$wrong_refs" -eq 0 ]]; then
        log_pass "no local skills reference scripts in wrong directory"
    else
        log_fail "found $wrong_refs wrong script path references in .claude/skills/"
        grep -rn "iikit-0[0-9]-[a-z]*/scripts/" "$base"/iikit-*/SKILL.md 2>/dev/null | head -5
    fi

    # Should use .claude/skills/iikit-core/scripts/bash/ paths
    ((TESTS_RUN++))
    local correct_bash_refs
    correct_bash_refs=$(grep -rh "\.claude/skills/iikit-core/scripts/bash/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$correct_bash_refs" -gt 0 ]]; then
        log_pass "local skills use .claude/skills/iikit-core/scripts/bash/ ($correct_bash_refs refs)"
    else
        log_fail "local skills don't use .claude/skills/iikit-core/scripts/bash/"
    fi

    # Should use .claude/skills/iikit-core/scripts/powershell/ paths (where applicable)
    ((TESTS_RUN++))
    local correct_ps_refs
    correct_ps_refs=$(grep -rh "\.claude/skills/iikit-core/scripts/powershell/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$correct_ps_refs" -gt 0 ]]; then
        log_pass "local skills use .claude/skills/iikit-core/scripts/powershell/ ($correct_ps_refs refs)"
    else
        log_warn "local skills have no PowerShell script references (may be OK)"
    fi

    # No references to .specify/scripts/ (deprecated)
    ((TESTS_RUN++))
    if grep -rq "\.specify/scripts/" "$base"/iikit-*/SKILL.md 2>/dev/null; then
        log_fail "local skills reference deprecated .specify/scripts/"
        grep -rn "\.specify/scripts/" "$base"/iikit-*/SKILL.md 2>/dev/null | head -3
    else
        log_pass "no references to deprecated .specify/scripts/"
    fi
}

test_tiles_script_paths() {
    log_section "Tiles Distribution Script Paths (tiles/intent-integrity-kit/)"
    local base="tiles/intent-integrity-kit/skills"

    [[ ! -d "$base" ]] && { log_info "tiles/intent-integrity-kit/ not found, skipping"; return; }

    # All SKILL.md files should reference scripts at iikit-core/scripts/
    ((TESTS_RUN++))
    local wrong_refs
    wrong_refs=$(grep -rh "iikit-0[0-9]-[a-z]*/scripts/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$wrong_refs" -eq 0 ]]; then
        log_pass "no tile skills reference scripts in wrong directory"
    else
        log_fail "found $wrong_refs wrong script path references in tiles/"
        grep -rn "iikit-0[0-9]-[a-z]*/scripts/" "$base"/iikit-*/SKILL.md 2>/dev/null | head -5
    fi

    # Should use iikit-core/scripts/bash/ paths
    ((TESTS_RUN++))
    local correct_bash_refs
    correct_bash_refs=$(grep -rh "iikit-core/scripts/bash/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$correct_bash_refs" -gt 0 ]]; then
        log_pass "tile skills use iikit-core/scripts/bash/ ($correct_bash_refs refs)"
    else
        log_fail "tile skills don't use iikit-core/scripts/bash/"
    fi

    # Should use iikit-core/scripts/powershell/ paths (where applicable)
    ((TESTS_RUN++))
    local correct_ps_refs
    correct_ps_refs=$(grep -rh "iikit-core/scripts/powershell/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$correct_ps_refs" -gt 0 ]]; then
        log_pass "tile skills use iikit-core/scripts/powershell/ ($correct_ps_refs refs)"
    else
        log_warn "tile skills have no PowerShell script references (may be OK)"
    fi
}

test_tiles_bash_command_paths() {
    log_section "Tiles Bash Command Paths (must be absolute .tessl/...)"
    local base="tiles/intent-integrity-kit/skills"

    [[ ! -d "$base" ]] && { log_info "tiles/intent-integrity-kit/ not found, skipping"; return; }

    # Bash commands MUST use .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/ prefix
    # This is the installed path when users run tessl install
    ((TESTS_RUN++))
    local correct_bash_cmds
    correct_bash_cmds=$(grep -rh "bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$correct_bash_cmds" -gt 0 ]]; then
        log_pass "tile bash commands use full .tessl/tiles/... path ($correct_bash_cmds refs)"
    else
        log_fail "tile bash commands don't use .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/ path"
    fi

    # Bash commands MUST NOT use relative ../iikit-core/ paths (would break at runtime)
    ((TESTS_RUN++))
    local broken_bash_cmds
    broken_bash_cmds=$(grep -rE "^bash \.\./iikit-core/|^   bash \.\./iikit-core/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$broken_bash_cmds" -eq 0 ]]; then
        log_pass "no tile bash commands use broken relative ../iikit-core/ path"
    else
        log_fail "found $broken_bash_cmds bash commands with broken relative path"
        grep -rn "bash \.\./iikit-core/" "$base"/iikit-*/SKILL.md 2>/dev/null | head -3
    fi

    # PowerShell commands MUST use .tessl/tiles/ prefix
    ((TESTS_RUN++))
    local correct_pwsh_cmds
    correct_pwsh_cmds=$(grep -rh "pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$correct_pwsh_cmds" -gt 0 ]]; then
        log_pass "tile pwsh commands use full .tessl/tiles/... path ($correct_pwsh_cmds refs)"
    else
        log_warn "tile pwsh commands may not use .tessl/tiles/ path (check manually)"
    fi
}

test_tiles_markdown_link_paths() {
    log_section "Tiles Markdown Link Paths (must be relative ../iikit-core/)"
    local base="tiles/intent-integrity-kit/skills"

    [[ ! -d "$base" ]] && { log_info "tiles/intent-integrity-kit/ not found, skipping"; return; }

    # Markdown links to templates SHOULD use relative ../iikit-core/templates/ path
    # This allows tessl tile publish validation to work
    ((TESTS_RUN++))
    local correct_md_links
    correct_md_links=$(grep -rh '\](../iikit-core/templates/' "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$correct_md_links" -gt 0 ]]; then
        log_pass "tile markdown links use relative ../iikit-core/templates/ ($correct_md_links refs)"
    else
        log_fail "tile markdown links don't use ../iikit-core/templates/ path"
    fi

    # Markdown links MUST NOT use .tessl/tiles/ (wrong for validation)
    ((TESTS_RUN++))
    local wrong_md_links
    wrong_md_links=$(grep -rh '\](.tessl/tiles/' "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$wrong_md_links" -eq 0 ]]; then
        log_pass "no tile markdown links use .tessl/tiles/ path"
    else
        log_fail "found $wrong_md_links markdown links with wrong .tessl/tiles/ path"
    fi

    # Markdown links MUST NOT use .claude/skills/ (local dev path)
    ((TESTS_RUN++))
    local local_md_links
    local_md_links=$(grep -rh '\](.claude/skills/' "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$local_md_links" -eq 0 ]]; then
        log_pass "no tile markdown links use .claude/skills/ path"
    else
        log_fail "found $local_md_links markdown links with .claude/skills/ path"
    fi
}

test_readme_paths() {
    log_section "README.md Path Consistency"

    [[ ! -f "README.md" ]] && { log_info "README.md not found, skipping"; return; }

    # No references to .specify/scripts/ (deprecated)
    ((TESTS_RUN++))
    if grep -q "\.specify/scripts/" README.md 2>/dev/null; then
        log_fail "README.md references deprecated .specify/scripts/"
        grep -n "\.specify/scripts/" README.md | head -3
    else
        log_pass "README.md has no .specify/scripts/ references"
    fi

    # No references to .specify/templates/ (deprecated)
    ((TESTS_RUN++))
    if grep -q "\.specify/templates/" README.md 2>/dev/null; then
        log_fail "README.md references deprecated .specify/templates/"
    else
        log_pass "README.md has no .specify/templates/ references"
    fi

    # Should reference .claude/skills/iikit-core/scripts/
    ((TESTS_RUN++))
    if grep -q "\.claude/skills/iikit-core/scripts/" README.md 2>/dev/null; then
        log_pass "README.md uses correct script paths"
    else
        log_warn "README.md may not reference current script paths"
    fi

    # Project structure should not show .specify/scripts/ or .specify/templates/
    ((TESTS_RUN++))
    if grep -A30 "Project Structure" README.md 2>/dev/null | grep -qE "scripts/bash|scripts/powershell|templates/" | grep -v "iikit-core"; then
        # Check if it's under .specify (wrong) or .claude (right)
        if grep -A30 "Project Structure" README.md 2>/dev/null | grep -q "\.specify.*scripts"; then
            log_fail "README project structure shows .specify/scripts/ (deprecated)"
        else
            log_pass "README project structure is correct"
        fi
    else
        log_pass "README project structure doesn't show deprecated paths"
    fi
}

test_agents_md_paths() {
    log_section "AGENTS.md / CLAUDE.md Path Consistency"

    local agent_file=""
    [[ -f "AGENTS.md" ]] && agent_file="AGENTS.md"
    [[ -f "CLAUDE.md" ]] && agent_file="CLAUDE.md"

    [[ -z "$agent_file" ]] && { log_info "No agent file found, skipping"; return; }

    # No references to .specify/scripts/
    ((TESTS_RUN++))
    if grep -q "\.specify/scripts/" "$agent_file" 2>/dev/null; then
        log_fail "$agent_file references deprecated .specify/scripts/"
    else
        log_pass "$agent_file has no .specify/scripts/ references"
    fi

    # Should reference .claude/skills/iikit-core/scripts/
    ((TESTS_RUN++))
    if grep -q "\.claude/skills/iikit-core/scripts/" "$agent_file" 2>/dev/null; then
        log_pass "$agent_file uses correct script paths"
    else
        log_warn "$agent_file may need script path update"
    fi
}

test_api_reference_paths() {
    log_section "API-REFERENCE.md Path Consistency"

    [[ ! -f "API-REFERENCE.md" ]] && { log_info "API-REFERENCE.md not found, skipping"; return; }

    # No references to .specify/scripts/
    ((TESTS_RUN++))
    if grep -q "\.specify/scripts/" API-REFERENCE.md 2>/dev/null; then
        log_fail "API-REFERENCE.md references deprecated .specify/scripts/"
        grep -n "\.specify/scripts/" API-REFERENCE.md | head -3
    else
        log_pass "API-REFERENCE.md has no .specify/scripts/ references"
    fi

    # Platform support table should use correct paths
    ((TESTS_RUN++))
    if grep -A5 "Platform Support" API-REFERENCE.md 2>/dev/null | grep -q "\.specify/scripts/"; then
        log_fail "API-REFERENCE.md platform table has deprecated paths"
    else
        log_pass "API-REFERENCE.md platform table is correct"
    fi
}

test_framework_principles_paths() {
    log_section "FRAMEWORK-PRINCIPLES.md Path Consistency"

    [[ ! -f "FRAMEWORK-PRINCIPLES.md" ]] && { log_info "FRAMEWORK-PRINCIPLES.md not found, skipping"; return; }

    # No references to .specify/scripts/
    ((TESTS_RUN++))
    if grep -q "\.specify/scripts/" FRAMEWORK-PRINCIPLES.md 2>/dev/null; then
        log_fail "FRAMEWORK-PRINCIPLES.md references deprecated .specify/scripts/"
    else
        log_pass "FRAMEWORK-PRINCIPLES.md has no deprecated paths"
    fi
}

test_testing_strategy_paths() {
    log_section "TESTING_STRATEGY.md Path Consistency"

    [[ ! -f "TESTING_STRATEGY.md" ]] && { log_info "TESTING_STRATEGY.md not found, skipping"; return; }

    # Should use .claude/skills/iikit-core/scripts/ or be clearly historical
    ((TESTS_RUN++))
    local deprecated_count
    deprecated_count=$(grep -c "\.specify/scripts/" TESTING_STRATEGY.md 2>/dev/null || echo "0")
    deprecated_count="${deprecated_count//[^0-9]/}"  # Strip non-digits
    if [[ "$deprecated_count" -gt 0 ]]; then
        log_fail "TESTING_STRATEGY.md has $deprecated_count deprecated path references"
    else
        log_pass "TESTING_STRATEGY.md has no deprecated paths"
    fi
}

test_skill_numbering() {
    log_section "Skill Numbering Consistency"
    local base=".claude/skills"

    # Check all skills exist with correct numbering
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
        if [[ -d "$base/$skill" && -f "$base/$skill/SKILL.md" ]]; then
            log_pass "skill exists: $skill"
        else
            log_fail "skill missing: $skill"
        fi
    done
}

test_scripts_exist() {
    log_section "Scripts Exist at Correct Location"

    # Bash scripts
    local bash_base=".claude/skills/iikit-core/scripts/bash"
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
            log_pass "bash script exists: $script"
        else
            log_fail "bash script missing: $bash_base/$script"
        fi
    done

    # PowerShell scripts
    local ps_base=".claude/skills/iikit-core/scripts/powershell"
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
            log_pass "powershell script exists: $script"
        else
            log_fail "powershell script missing: $ps_base/$script"
        fi
    done
}

test_templates_exist() {
    log_section "Templates Exist at Correct Location"
    local base=".claude/skills/iikit-core/templates"

    local templates=(
        "constitution-template.md"
        "spec-template.md"
        "plan-template.md"
        "tasks-template.md"
        "checklist-template.md"
        "testspec-template.md"
        "agent-file-template.md"
    )

    for template in "${templates[@]}"; do
        ((TESTS_RUN++))
        if [[ -f "$base/$template" ]]; then
            log_pass "template exists: $template"
        else
            log_fail "template missing: $base/$template"
        fi
    done
}

test_specify_directory() {
    log_section ".specify/README.md Consistency"

    [[ ! -f ".specify/README.md" ]] && { log_info ".specify/README.md not found, skipping"; return; }

    # Should not reference .specify/templates/
    ((TESTS_RUN++))
    if grep -q "\.specify/templates/" .specify/README.md 2>/dev/null; then
        log_fail ".specify/README.md references deprecated .specify/templates/"
    else
        log_pass ".specify/README.md has correct template path"
    fi
}

test_local_vs_tiles_sync() {
    log_section "Local Skills vs Tiles Sync"

    [[ ! -d "tiles/intent-integrity-kit/skills" ]] && { log_info "tiles/ not found, skipping sync check"; return; }

    # Check that local and tiles have same skills
    local local_skills tiles_skills
    local_skills=$(ls -1 .claude/skills/ 2>/dev/null | grep "^iikit-" | sort)
    tiles_skills=$(ls -1 tiles/intent-integrity-kit/skills/ 2>/dev/null | grep "^iikit-" | sort)

    ((TESTS_RUN++))
    if [[ "$local_skills" == "$tiles_skills" ]]; then
        log_pass "local and tiles have same skills"
    else
        log_fail "local and tiles skills mismatch"
        log_info "Local only: $(comm -23 <(echo "$local_skills") <(echo "$tiles_skills") | tr '\n' ' ')"
        log_info "Tiles only: $(comm -13 <(echo "$local_skills") <(echo "$tiles_skills") | tr '\n' ' ')"
    fi
}

test_bash_script_template_refs() {
    log_section "Bash Script Inner Template References"
    local base=".claude/skills/iikit-core/scripts/bash"
    local templates_dir=".claude/skills/iikit-core/templates"

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
            grep -n "template" "$base/$script" 2>/dev/null | head -2
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
        grep -rn "\.specify/templates/" "$base"/*.sh 2>/dev/null | head -3
    else
        log_pass "no bash scripts reference deprecated .specify/templates/"
    fi
}

test_powershell_script_template_refs() {
    log_section "PowerShell Script Inner Template References"
    local base=".claude/skills/iikit-core/scripts/powershell"
    local templates_dir=".claude/skills/iikit-core/templates"

    # Scripts that reference templates - verify they use relative ..\..\templates\ path
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
            log_fail "powershell script not found: $script"
            continue
        fi

        # Check that script references the template via relative path (PowerShell uses backslashes)
        if grep -qE '\.\.\\\.\.\\templates\\'"$template|"'\.\.\/\.\.\/templates\/'"$template" "$base/$script" 2>/dev/null; then
            log_pass "$script references $template correctly"
        else
            log_fail "$script doesn't use relative ..\\..\\templates\\$template path"
            grep -in "template" "$base/$script" 2>/dev/null | head -2
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
        grep -rn "\.specify[/\\]templates" "$base"/*.ps1 2>/dev/null | head -3
    else
        log_pass "no powershell scripts reference deprecated .specify/templates/"
    fi
}

test_skill_template_references() {
    log_section "SKILL.md Template References (Local)"
    local base=".claude/skills"

    # All template references in local SKILL.md should use .claude/skills/iikit-core/templates/
    ((TESTS_RUN++))
    local wrong_template_refs
    wrong_template_refs=$(grep -rh "iikit-0[0-9]-[a-z]*/templates/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$wrong_template_refs" -eq 0 ]]; then
        log_pass "no local skills reference templates in wrong directory"
    else
        log_fail "found $wrong_template_refs wrong template path references"
        grep -rn "iikit-0[0-9]-[a-z]*/templates/" "$base"/iikit-*/SKILL.md 2>/dev/null | head -5
    fi

    # Should use .claude/skills/iikit-core/templates/ paths
    ((TESTS_RUN++))
    local correct_refs
    correct_refs=$(grep -rh "\.claude/skills/iikit-core/templates/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$correct_refs" -gt 0 ]]; then
        log_pass "local skills use .claude/skills/iikit-core/templates/ ($correct_refs refs)"
    else
        log_warn "no template references found in local skills (may be OK)"
    fi

    # No deprecated .specify/templates/ references
    ((TESTS_RUN++))
    if grep -rq "\.specify/templates/" "$base"/iikit-*/SKILL.md 2>/dev/null; then
        log_fail "local skills reference deprecated .specify/templates/"
        grep -rn "\.specify/templates/" "$base"/iikit-*/SKILL.md 2>/dev/null | head -3
    else
        log_pass "no local skills reference deprecated .specify/templates/"
    fi
}

test_tiles_skill_template_references() {
    log_section "SKILL.md Template References (Tiles)"
    local base="tiles/intent-integrity-kit/skills"

    [[ ! -d "$base" ]] && { log_info "tiles/intent-integrity-kit/ not found, skipping"; return; }

    # All template references in tiles SKILL.md should use iikit-core/templates/
    ((TESTS_RUN++))
    local wrong_template_refs
    wrong_template_refs=$(grep -rh "iikit-0[0-9]-[a-z]*/templates/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$wrong_template_refs" -eq 0 ]]; then
        log_pass "no tile skills reference templates in wrong directory"
    else
        log_fail "found $wrong_template_refs wrong template path references in tiles"
        grep -rn "iikit-0[0-9]-[a-z]*/templates/" "$base"/iikit-*/SKILL.md 2>/dev/null | head -5
    fi

    # Should use iikit-core/templates/ paths
    ((TESTS_RUN++))
    local correct_refs
    correct_refs=$(grep -rh "iikit-core/templates/" "$base"/iikit-*/SKILL.md 2>/dev/null | wc -l)
    if [[ "$correct_refs" -gt 0 ]]; then
        log_pass "tile skills use iikit-core/templates/ ($correct_refs refs)"
    else
        log_warn "no template references found in tile skills (may be OK)"
    fi

    # No deprecated .specify/templates/ references
    ((TESTS_RUN++))
    if grep -rq "\.specify/templates/" "$base"/iikit-*/SKILL.md 2>/dev/null; then
        log_fail "tile skills reference deprecated .specify/templates/"
    else
        log_pass "no tile skills reference deprecated .specify/templates/"
    fi
}

test_all_documentation_template_refs() {
    log_section "Documentation Template References"

    # List of all documentation files to check
    local doc_files=(
        "README.md"
        "CLAUDE.md"
        "AGENTS.md"
        "FRAMEWORK-PRINCIPLES.md"
        "API-REFERENCE.md"
        "TESTING_STRATEGY.md"
        "WORK_SUMMARY.md"
    )

    for doc in "${doc_files[@]}"; do
        [[ ! -f "$doc" ]] && continue

        # No deprecated .specify/templates/ references
        ((TESTS_RUN++))
        if grep -q "\.specify/templates/" "$doc" 2>/dev/null; then
            log_fail "$doc references deprecated .specify/templates/"
            grep -n "\.specify/templates/" "$doc" 2>/dev/null | head -2
        else
            log_pass "$doc has no deprecated .specify/templates/"
        fi
    done

    # Check .specify/README.md specifically (it's in a subdirectory)
    if [[ -f ".specify/README.md" ]]; then
        ((TESTS_RUN++))
        if grep -q "\.specify/templates/" ".specify/README.md" 2>/dev/null; then
            log_fail ".specify/README.md references deprecated .specify/templates/"
        else
            log_pass ".specify/README.md has no deprecated .specify/templates/"
        fi
    fi
}

test_all_templates_are_referenced() {
    log_section "All Templates Are Referenced"
    local templates_dir=".claude/skills/iikit-core/templates"
    local skills_dir=".claude/skills"
    local scripts_dir=".claude/skills/iikit-core/scripts"

    # Get all template files
    for template in "$templates_dir"/*.md; do
        [[ ! -f "$template" ]] && continue
        local template_name=$(basename "$template")
        ((TESTS_RUN++))

        # Check if referenced in SKILL.md files OR in scripts
        local found=false

        # Check SKILL.md files
        if grep -rq "$template_name" "$skills_dir"/iikit-*/SKILL.md 2>/dev/null; then
            found=true
        fi

        # Check bash scripts
        if grep -rq "$template_name" "$scripts_dir/bash"/*.sh 2>/dev/null; then
            found=true
        fi

        # Check PowerShell scripts
        if grep -rq "$template_name" "$scripts_dir/powershell"/*.ps1 2>/dev/null; then
            found=true
        fi

        if [[ "$found" == "true" ]]; then
            log_pass "$template_name is referenced"
        else
            log_fail "$template_name exists but is NOT referenced anywhere"
        fi
    done
}

test_tiles_script_inner_template_refs() {
    log_section "Tiles Script Inner Template References"
    local base="tiles/intent-integrity-kit/skills/iikit-core/scripts"

    [[ ! -d "$base" ]] && { log_info "tiles scripts not found, skipping"; return; }

    # Bash scripts
    ((TESTS_RUN++))
    if grep -rq "\.specify/templates/" "$base/bash"/*.sh 2>/dev/null; then
        log_fail "tiles bash scripts reference deprecated .specify/templates/"
    else
        log_pass "tiles bash scripts have no deprecated template refs"
    fi

    # PowerShell scripts
    ((TESTS_RUN++))
    if grep -rq "\.specify[/\\]templates" "$base/powershell"/*.ps1 2>/dev/null; then
        log_fail "tiles powershell scripts reference deprecated .specify/templates/"
    else
        log_pass "tiles powershell scripts have no deprecated template refs"
    fi

    # Verify bash scripts use ../../templates/ relative path
    ((TESTS_RUN++))
    local bash_template_refs
    bash_template_refs=$(grep -rh "TEMPLATE.*=" "$base/bash"/*.sh 2>/dev/null | grep -c '../../templates/' || echo "0")
    if [[ "$bash_template_refs" -gt 0 ]]; then
        log_pass "tiles bash scripts use relative ../../templates/ ($bash_template_refs refs)"
    else
        log_warn "tiles bash scripts may not have template refs (checking...)"
    fi

    # Verify powershell scripts use ..\..\templates\ relative path
    ((TESTS_RUN++))
    local ps_template_refs
    ps_template_refs=$(grep -rh '\$template\|TEMPLATE' "$base/powershell"/*.ps1 2>/dev/null | grep -cE '\.\.\\\.\.\\templates|\.\.\/\.\.\/templates' || echo "0")
    if [[ "$ps_template_refs" -gt 0 ]]; then
        log_pass "tiles powershell scripts use relative ..\\..\\templates\\ ($ps_template_refs refs)"
    else
        log_warn "tiles powershell scripts may not have template refs (checking...)"
    fi
}

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║     Intent Integrity Kit Source Validation Tests          ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    log_info "Repo root: $REPO_ROOT"

    test_local_skills_script_paths
    test_tiles_script_paths
    test_tiles_bash_command_paths
    test_tiles_markdown_link_paths
    test_readme_paths
    test_agents_md_paths
    test_api_reference_paths
    test_framework_principles_paths
    test_testing_strategy_paths
    test_skill_numbering
    test_scripts_exist
    test_templates_exist
    test_specify_directory
    test_local_vs_tiles_sync
    test_bash_script_template_refs
    test_powershell_script_template_refs
    test_skill_template_references
    test_tiles_skill_template_references
    test_all_documentation_template_refs
    test_all_templates_are_referenced
    test_tiles_script_inner_template_refs

    log_section "Summary"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"

    [[ $TESTS_FAILED -gt 0 ]] && exit 1
    exit 0
}

main "$@"
