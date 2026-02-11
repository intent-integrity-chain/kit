#!/usr/bin/env bash
# Common functions and variables for all scripts

# Get repository root, with fallback for non-git repositories
get_repo_root() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
    else
        # Fall back to script location for non-git repos
        local script_dir="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        (cd "$script_dir/../../../../.." && pwd)
    fi
}

# Get current branch, with fallback for non-git repositories
get_current_branch() {
    # First check if SPECIFY_FEATURE environment variable is set
    if [[ -n "${SPECIFY_FEATURE:-}" ]]; then
        echo "$SPECIFY_FEATURE"
        return
    fi

    # Then check git if available
    if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
        git rev-parse --abbrev-ref HEAD
        return
    fi

    # For non-git repos, try to find the latest feature directory
    local repo_root=$(get_repo_root)
    local specs_dir="$repo_root/specs"

    if [[ -d "$specs_dir" ]]; then
        local latest_feature=""
        local highest=0

        for dir in "$specs_dir"/*; do
            if [[ -d "$dir" ]]; then
                local dirname=$(basename "$dir")
                if [[ "$dirname" =~ ^([0-9]{3})- ]]; then
                    local number=${BASH_REMATCH[1]}
                    number=$((10#$number))
                    if [[ "$number" -gt "$highest" ]]; then
                        highest=$number
                        latest_feature=$dirname
                    fi
                fi
            fi
        done

        if [[ -n "$latest_feature" ]]; then
            echo "$latest_feature"
            return
        fi
    fi

    echo "main"  # Final fallback
}

# Check if we have git available
has_git() {
    git rev-parse --show-toplevel >/dev/null 2>&1
}

check_feature_branch() {
    local branch="$1"
    local has_git_repo="$2"

    # For non-git repos, we can't enforce branch naming but still provide output
    if [[ "$has_git_repo" != "true" ]]; then
        echo "[specify] Warning: Git repository not detected; skipped branch validation" >&2
        return 0
    fi

    # Accept if branch matches NNN- pattern (standard feature branch)
    if [[ "$branch" =~ ^[0-9]{3}- ]]; then
        return 0
    fi

    # Accept if SPECIFY_FEATURE env var is set (explicit feature context, e.g., --skip-branch)
    if [[ -n "${SPECIFY_FEATURE:-}" ]]; then
        echo "[specify] Using feature context from SPECIFY_FEATURE: $SPECIFY_FEATURE" >&2
        return 0
    fi

    # Check if there are feature directories we can use
    local repo_root=$(get_repo_root)
    local specs_dir="$repo_root/specs"
    local feature_count=0
    local latest_feature=""

    if [[ -d "$specs_dir" ]]; then
        for dir in "$specs_dir"/*; do
            if [[ -d "$dir" ]] && [[ "$(basename "$dir")" =~ ^[0-9]{3}- ]]; then
                feature_count=$((feature_count + 1))
                latest_feature=$(basename "$dir")
            fi
        done
    fi

    if [[ "$feature_count" -eq 1 ]]; then
        echo "[specify] Not on feature branch, but found single feature directory: $latest_feature" >&2
        export SPECIFY_FEATURE="$latest_feature"
        return 0
    elif [[ "$feature_count" -gt 1 ]]; then
        echo "WARNING: Not on a feature branch and multiple feature directories exist." >&2
        echo "Current branch: $branch" >&2
        echo "Set SPECIFY_FEATURE=<feature-name> to specify which feature to use." >&2
        echo "Or run: /iikit-01-specify to create a new feature." >&2
        return 1
    fi

    echo "ERROR: Not on a feature branch. Current branch: $branch" >&2
    echo "Run: /iikit-01-specify <feature description>" >&2
    return 1
}

get_feature_dir() { echo "$1/specs/$2"; }

# Find feature directory by numeric prefix instead of exact branch match
# This allows multiple branches to work on the same spec (e.g., 004-fix-bug, 004-add-feature)
find_feature_dir_by_prefix() {
    local repo_root="$1"
    local branch_name="$2"
    local specs_dir="$repo_root/specs"

    # Extract numeric prefix from branch (e.g., "004" from "004-whatever")
    if [[ ! "$branch_name" =~ ^([0-9]{3})- ]]; then
        # If branch doesn't have numeric prefix, fall back to exact match
        echo "$specs_dir/$branch_name"
        return
    fi

    local prefix="${BASH_REMATCH[1]}"

    # Search for directories in specs/ that start with this prefix
    local matches=()
    if [[ -d "$specs_dir" ]]; then
        for dir in "$specs_dir"/"$prefix"-*; do
            if [[ -d "$dir" ]]; then
                matches+=("$(basename "$dir")")
            fi
        done
    fi

    # Handle results
    if [[ ${#matches[@]} -eq 0 ]]; then
        # No match found - return the branch name path (will fail later with clear error)
        echo "$specs_dir/$branch_name"
    elif [[ ${#matches[@]} -eq 1 ]]; then
        # Exactly one match - perfect!
        echo "$specs_dir/${matches[0]}"
    else
        # Multiple matches - this shouldn't happen with proper naming convention
        echo "ERROR: Multiple spec directories found with prefix '$prefix': ${matches[*]}" >&2
        echo "Please ensure only one spec directory exists per numeric prefix." >&2
        echo "$specs_dir/$branch_name"  # Return something to avoid breaking the script
    fi
}

get_feature_paths() {
    local repo_root=$(get_repo_root)
    local current_branch=$(get_current_branch)
    local has_git_repo="false"

    if has_git; then
        has_git_repo="true"
    fi

    # Use prefix-based lookup to support multiple branches per spec
    local feature_dir=$(find_feature_dir_by_prefix "$repo_root" "$current_branch")

    cat <<EOF
REPO_ROOT='$repo_root'
CURRENT_BRANCH='$current_branch'
HAS_GIT='$has_git_repo'
FEATURE_DIR='$feature_dir'
FEATURE_SPEC='$feature_dir/spec.md'
IMPL_PLAN='$feature_dir/plan.md'
TASKS='$feature_dir/tasks.md'
RESEARCH='$feature_dir/research.md'
DATA_MODEL='$feature_dir/data-model.md'
QUICKSTART='$feature_dir/quickstart.md'
CONTRACTS_DIR='$feature_dir/contracts'
EOF
}

check_file() { [[ -f "$1" ]] && echo "  [Y] $2" || echo "  [N] $2"; }
check_dir() { [[ -d "$1" && -n $(ls -A "$1" 2>/dev/null) ]] && echo "  [Y] $2" || echo "  [N] $2"; }

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Validate constitution exists
validate_constitution() {
    local repo_root="$1"
    local constitution="$repo_root/CONSTITUTION.md"

    if [[ ! -f "$constitution" ]]; then
        echo "ERROR: Constitution not found at $constitution" >&2
        echo "Run /iikit-00-constitution first to define project principles." >&2
        return 1
    fi

    # Check for required sections
    if ! grep -q "^## .*Principles\|^# .*Constitution" "$constitution" 2>/dev/null; then
        echo "WARNING: Constitution may be incomplete - missing principles section" >&2
    fi

    return 0
}

# Validate spec.md exists and has required structure
validate_spec() {
    local spec_file="$1"
    local errors=0

    if [[ ! -f "$spec_file" ]]; then
        echo "ERROR: spec.md not found at $spec_file" >&2
        echo "Run /iikit-01-specify first to create the feature specification." >&2
        return 1
    fi

    # Check for required sections
    if ! grep -q "^## Requirements\|^## Functional Requirements\|^### Functional Requirements" "$spec_file" 2>/dev/null; then
        echo "ERROR: spec.md missing 'Requirements' section" >&2
        ((errors++))
    fi

    if ! grep -q "^## Success Criteria" "$spec_file" 2>/dev/null; then
        echo "ERROR: spec.md missing 'Success Criteria' section" >&2
        ((errors++))
    fi

    if ! grep -q "^## User Scenarios\|^### User Story" "$spec_file" 2>/dev/null; then
        echo "ERROR: spec.md missing 'User Scenarios' or 'User Story' section" >&2
        ((errors++))
    fi

    # Check for unresolved clarifications
    if grep -q "\[NEEDS CLARIFICATION" "$spec_file" 2>/dev/null; then
        local count=$(grep -c "\[NEEDS CLARIFICATION" "$spec_file" 2>/dev/null || echo "0")
        echo "WARNING: spec.md has $count unresolved [NEEDS CLARIFICATION] markers" >&2
        echo "Consider running /iikit-02-clarify to resolve them." >&2
    fi

    [[ $errors -gt 0 ]] && return 1
    return 0
}

# Validate plan.md exists and has required structure
validate_plan() {
    local plan_file="$1"
    local errors=0

    if [[ ! -f "$plan_file" ]]; then
        echo "ERROR: plan.md not found at $plan_file" >&2
        echo "Run /iikit-03-plan first to create the implementation plan." >&2
        return 1
    fi

    # Check for required sections
    if ! grep -q "^## Technical Context\|^\*\*Language/Version\*\*" "$plan_file" 2>/dev/null; then
        echo "WARNING: plan.md may be incomplete - missing Technical Context" >&2
    fi

    # Check for unresolved clarifications
    if grep -q "NEEDS CLARIFICATION" "$plan_file" 2>/dev/null; then
        local count=$(grep -c "NEEDS CLARIFICATION" "$plan_file" 2>/dev/null || echo "0")
        echo "WARNING: plan.md has $count unresolved NEEDS CLARIFICATION items" >&2
    fi

    return 0
}

# Validate tasks.md exists and has required structure
validate_tasks() {
    local tasks_file="$1"

    if [[ ! -f "$tasks_file" ]]; then
        echo "ERROR: tasks.md not found at $tasks_file" >&2
        echo "Run /iikit-06-tasks first to create the task list." >&2
        return 1
    fi

    # Check for at least one task
    if ! grep -q "^- \[ \]\|^- \[x\]\|^- \[X\]" "$tasks_file" 2>/dev/null; then
        echo "WARNING: tasks.md appears to have no task items" >&2
    fi

    return 0
}

# Calculate spec quality score (0-10)
calculate_spec_quality() {
    local spec_file="$1"
    local score=0

    [[ ! -f "$spec_file" ]] && echo "0" && return

    # +2 for having requirements section
    grep -q "^## Requirements\|^### Functional Requirements" "$spec_file" 2>/dev/null && ((score+=2))

    # +2 for having success criteria
    grep -q "^## Success Criteria" "$spec_file" 2>/dev/null && ((score+=2))

    # +2 for having user scenarios
    grep -q "^## User Scenarios\|^### User Story" "$spec_file" 2>/dev/null && ((score+=2))

    # +1 for having at least 3 requirements
    local req_count
    req_count=$(grep -c "^- \*\*FR-\|^- FR-" "$spec_file" 2>/dev/null) || req_count=0
    [[ $req_count -ge 3 ]] && ((score+=1))

    # +1 for having at least 3 success criteria
    local sc_count
    sc_count=$(grep -c "^- \*\*SC-\|^- SC-" "$spec_file" 2>/dev/null) || sc_count=0
    [[ $sc_count -ge 3 ]] && ((score+=1))

    # +1 for no NEEDS CLARIFICATION markers
    ! grep -q "\[NEEDS CLARIFICATION" "$spec_file" 2>/dev/null && ((score+=1))

    # +1 for having edge cases section
    grep -q "^### Edge Cases\|^## Edge Cases" "$spec_file" 2>/dev/null && ((score+=1))

    echo "$score"
}
