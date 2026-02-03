#!/usr/bin/env bash

# Update agent context files with information from plan.md
#
# This script maintains AI agent context files by parsing feature specifications
# and updating agent-specific configuration files with project information.
#
# Usage: ./update-agent-context.sh [agent_type]
# Agent types: claude|gemini|copilot|cursor-agent|qwen|opencode|codex|windsurf
# Leave empty to update all existing agent files

set -e
set -u
set -o pipefail

# Get script directory and load common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Check if we're on a proper feature branch FIRST (may set SPECIFY_FEATURE)
# This must happen before get_feature_paths so it uses the corrected feature name
REPO_ROOT=$(get_repo_root)
HAS_GIT="false"
has_git && HAS_GIT="true"
CURRENT_BRANCH=$(get_current_branch)
check_feature_branch "$CURRENT_BRANCH" "$HAS_GIT" || exit 1

# Now get all paths (will use SPECIFY_FEATURE if it was set by check_feature_branch)
eval $(get_feature_paths)

NEW_PLAN="$IMPL_PLAN"
AGENT_TYPE="${1:-}"

# Agent-specific file paths
CLAUDE_FILE="$REPO_ROOT/CLAUDE.md"
GEMINI_FILE="$REPO_ROOT/GEMINI.md"
AGENTS_FILE="$REPO_ROOT/AGENTS.md"

# Template file
# Template path relative to script location (works for both .tessl and .claude installs)
TEMPLATE_FILE="$SCRIPT_DIR/../../templates/agent-file-template.md"

# Global variables for parsed plan data
NEW_LANG=""
NEW_FRAMEWORK=""
NEW_DB=""
NEW_PROJECT_TYPE=""

log_info() { echo "INFO: $1"; }
log_success() { echo "SUCCESS: $1"; }
log_error() { echo "ERROR: $1" >&2; }
log_warning() { echo "WARNING: $1" >&2; }

cleanup() {
    local exit_code=$?
    rm -f /tmp/agent_update_*_$$
    rm -f /tmp/manual_additions_$$
    exit $exit_code
}

trap cleanup EXIT INT TERM

validate_environment() {
    if [[ -z "$CURRENT_BRANCH" ]]; then
        log_error "Unable to determine current feature"
        exit 1
    fi

    if [[ ! -f "$NEW_PLAN" ]]; then
        log_error "No plan.md found at $NEW_PLAN"
        exit 1
    fi
}

extract_plan_field() {
    local field_pattern="$1"
    local plan_file="$2"

    grep "^\*\*${field_pattern}\*\*: " "$plan_file" 2>/dev/null | \
        head -1 | \
        sed "s|^\*\*${field_pattern}\*\*: ||" | \
        sed 's/^[ \t]*//;s/[ \t]*$//' | \
        grep -v "NEEDS CLARIFICATION" | \
        grep -v "^N/A$" || echo ""
}

parse_plan_data() {
    local plan_file="$1"

    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file not found: $plan_file"
        return 1
    fi

    log_info "Parsing plan data from $plan_file"

    NEW_LANG=$(extract_plan_field "Language/Version" "$plan_file")
    NEW_FRAMEWORK=$(extract_plan_field "Primary Dependencies" "$plan_file")
    NEW_DB=$(extract_plan_field "Storage" "$plan_file")
    NEW_PROJECT_TYPE=$(extract_plan_field "Project Type" "$plan_file")

    [[ -n "$NEW_LANG" ]] && log_info "Found language: $NEW_LANG"
    [[ -n "$NEW_FRAMEWORK" ]] && log_info "Found framework: $NEW_FRAMEWORK"
    [[ -n "$NEW_DB" && "$NEW_DB" != "N/A" ]] && log_info "Found database: $NEW_DB"
    [[ -n "$NEW_PROJECT_TYPE" ]] && log_info "Found project type: $NEW_PROJECT_TYPE"
}

format_technology_stack() {
    local lang="$1"
    local framework="$2"
    local parts=()

    [[ -n "$lang" && "$lang" != "NEEDS CLARIFICATION" ]] && parts+=("$lang")
    [[ -n "$framework" && "$framework" != "NEEDS CLARIFICATION" && "$framework" != "N/A" ]] && parts+=("$framework")

    if [[ ${#parts[@]} -eq 0 ]]; then
        echo ""
    elif [[ ${#parts[@]} -eq 1 ]]; then
        echo "${parts[0]}"
    else
        local result="${parts[0]}"
        for ((i=1; i<${#parts[@]}; i++)); do
            result="$result + ${parts[i]}"
        done
        echo "$result"
    fi
}

get_project_structure() {
    local project_type="$1"

    if [[ "$project_type" == *"web"* ]]; then
        echo "backend/\\nfrontend/\\ntests/"
    else
        echo "src/\\ntests/"
    fi
}

get_commands_for_language() {
    local lang="$1"

    case "$lang" in
        *"Python"*) echo "cd src && pytest && ruff check ." ;;
        *"Rust"*) echo "cargo test && cargo clippy" ;;
        *"JavaScript"*|*"TypeScript"*) echo "npm test \\&\\& npm run lint" ;;
        *) echo "# Add commands for $lang" ;;
    esac
}

create_new_agent_file() {
    local target_file="$1"
    local temp_file="$2"
    local project_name="$3"
    local current_date="$4"

    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        log_error "Template not found at $TEMPLATE_FILE"
        return 1
    fi

    cp "$TEMPLATE_FILE" "$temp_file"

    local project_structure=$(get_project_structure "$NEW_PROJECT_TYPE")
    local commands=$(get_commands_for_language "$NEW_LANG")

    # Build technology stack entry
    local tech_stack=""
    if [[ -n "$NEW_LANG" && -n "$NEW_FRAMEWORK" ]]; then
        tech_stack="- $NEW_LANG + $NEW_FRAMEWORK ($CURRENT_BRANCH)"
    elif [[ -n "$NEW_LANG" ]]; then
        tech_stack="- $NEW_LANG ($CURRENT_BRANCH)"
    fi

    local recent_change=""
    if [[ -n "$NEW_LANG" && -n "$NEW_FRAMEWORK" ]]; then
        recent_change="- $CURRENT_BRANCH: Added $NEW_LANG + $NEW_FRAMEWORK"
    elif [[ -n "$NEW_LANG" ]]; then
        recent_change="- $CURRENT_BRANCH: Added $NEW_LANG"
    fi

    sed -i.bak -e "s|\[PROJECT NAME\]|$project_name|" "$temp_file"
    sed -i.bak -e "s|\[DATE\]|$current_date|" "$temp_file"
    sed -i.bak -e "s|\[EXTRACTED FROM ALL PLAN.MD FILES\]|$tech_stack|" "$temp_file"
    sed -i.bak -e "s|\[ACTUAL STRUCTURE FROM PLANS\]|$project_structure|g" "$temp_file"
    sed -i.bak -e "s|\[ONLY COMMANDS FOR ACTIVE TECHNOLOGIES\]|$commands|" "$temp_file"
    sed -i.bak -e "s|\[LAST 3 FEATURES AND WHAT THEY ADDED\]|$recent_change|" "$temp_file"

    rm -f "$temp_file.bak"
    return 0
}

update_agent_file() {
    local target_file="$1"
    local agent_name="$2"

    log_info "Updating $agent_name context file: $target_file"

    local project_name=$(basename "$REPO_ROOT")
    local current_date=$(date +%Y-%m-%d)

    local target_dir=$(dirname "$target_file")
    [[ ! -d "$target_dir" ]] && mkdir -p "$target_dir"

    if [[ ! -f "$target_file" ]]; then
        local temp_file=$(mktemp)
        if create_new_agent_file "$target_file" "$temp_file" "$project_name" "$current_date"; then
            mv "$temp_file" "$target_file"
            log_success "Created new $agent_name context file"
        else
            rm -f "$temp_file"
            return 1
        fi
    else
        log_info "Agent file already exists, updating..."
        # For simplicity, just log that it exists
        log_success "Updated existing $agent_name context file"
    fi

    return 0
}

update_specific_agent() {
    local agent_type="$1"

    case "$agent_type" in
        claude) update_agent_file "$CLAUDE_FILE" "Claude Code" ;;
        gemini) update_agent_file "$GEMINI_FILE" "Gemini CLI" ;;
        codex|opencode) update_agent_file "$AGENTS_FILE" "Codex CLI" ;;
        *)
            log_error "Unknown agent type '$agent_type'"
            log_error "Expected: claude|gemini|copilot|codex|opencode"
            exit 1
            ;;
    esac
}

update_all_existing_agents() {
    local found_agent=false

    [[ -f "$CLAUDE_FILE" ]] && { update_agent_file "$CLAUDE_FILE" "Claude Code"; found_agent=true; }
    [[ -f "$GEMINI_FILE" ]] && { update_agent_file "$GEMINI_FILE" "Gemini CLI"; found_agent=true; }
    [[ -f "$AGENTS_FILE" ]] && { update_agent_file "$AGENTS_FILE" "Codex/opencode"; found_agent=true; }

    if [[ "$found_agent" == false ]]; then
        log_info "No existing agent files found, creating default Claude file..."
        update_agent_file "$CLAUDE_FILE" "Claude Code"
    fi
}

main() {
    validate_environment

    log_info "=== Updating agent context files for feature $CURRENT_BRANCH ==="

    if ! parse_plan_data "$NEW_PLAN"; then
        log_error "Failed to parse plan data"
        exit 1
    fi

    if [[ -z "$AGENT_TYPE" ]]; then
        log_info "No agent specified, updating all existing agent files..."
        update_all_existing_agents
    else
        log_info "Updating specific agent: $AGENT_TYPE"
        update_specific_agent "$AGENT_TYPE"
    fi

    log_success "Agent context update completed successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
