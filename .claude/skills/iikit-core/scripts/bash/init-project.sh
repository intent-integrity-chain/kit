#!/usr/bin/env bash

# Initialize a intent-integrity-kit project with git
# Usage: init-project.sh [--json] [--commit-constitution]

set -e

JSON_MODE=false
COMMIT_CONSTITUTION=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
            shift
            ;;
        --commit-constitution)
            COMMIT_CONSTITUTION=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--json] [--commit-constitution]"
            echo ""
            echo "Initialize a intent-integrity-kit project with git repository."
            echo ""
            echo "Options:"
            echo "  --json                 Output in JSON format"
            echo "  --commit-constitution  Commit the constitution file after git init"
            echo "  --help, -h             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Use current working directory as project root
PROJECT_ROOT="$(pwd)"

# Check if .specify exists (validates this is a intent-integrity-kit project)
if [ ! -d "$PROJECT_ROOT/.specify" ]; then
    if $JSON_MODE; then
        printf '{"success":false,"error":"Not a intent-integrity-kit project: .specify directory not found","git_initialized":false}\n'
    else
        echo "Error: Not a intent-integrity-kit project. Directory .specify not found." >&2
    fi
    exit 1
fi

# Check if already a git repo
if [ -d "$PROJECT_ROOT/.git" ]; then
    GIT_INITIALIZED=false
    GIT_STATUS="already_initialized"
else
    # Initialize git
    git init "$PROJECT_ROOT" >/dev/null 2>&1
    GIT_INITIALIZED=true
    GIT_STATUS="initialized"
fi

# Install git hooks for assertion integrity enforcement
# install_hook <hook_type> <source_file> <marker>
# Sets RESULT_installed (true/false) and RESULT_status (installed/updated/installed_alongside/source_not_found/skipped)
install_hook() {
    local hook_type="$1"   # e.g., "pre-commit" or "post-commit"
    local source_file="$2" # e.g., "pre-commit-hook.sh"
    local marker="$3"      # e.g., "IIKIT-PRE-COMMIT"

    RESULT_installed=false
    RESULT_status="skipped"

    if [ ! -d "$PROJECT_ROOT/.git" ]; then
        return
    fi

    SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local hook_source="$SCRIPT_DIR/$source_file"

    if [ ! -f "$hook_source" ]; then
        RESULT_status="source_not_found"
        return
    fi

    local hooks_dir="$PROJECT_ROOT/.git/hooks"
    mkdir -p "$hooks_dir"
    local existing_hook="$hooks_dir/$hook_type"

    if [ ! -f "$existing_hook" ]; then
        # No existing hook — copy directly
        cp "$hook_source" "$existing_hook"
        chmod +x "$existing_hook"
        RESULT_installed=true
        RESULT_status="installed"
    elif grep -q "$marker" "$existing_hook" 2>/dev/null; then
        # Existing IIKit hook — update in place
        cp "$hook_source" "$existing_hook"
        chmod +x "$existing_hook"
        RESULT_installed=true
        RESULT_status="updated"
    else
        # Existing non-IIKit hook — install alongside
        local iikit_hook="$hooks_dir/iikit-$hook_type"
        cp "$hook_source" "$iikit_hook"
        chmod +x "$iikit_hook"
        # Append call to existing hook if not already present
        if ! grep -q "iikit-$hook_type" "$existing_hook" 2>/dev/null; then
            echo "" >> "$existing_hook"
            echo "# IIKit assertion integrity check" >> "$existing_hook"
            echo '"$(dirname "$0")/iikit-'"$hook_type"'"' >> "$existing_hook"
        fi
        RESULT_installed=true
        RESULT_status="installed_alongside"
    fi
}

# Install pre-commit hook (validates assertion hashes before commit)
install_hook "pre-commit" "pre-commit-hook.sh" "IIKIT-PRE-COMMIT"
HOOK_INSTALLED="$RESULT_installed"
HOOK_STATUS="$RESULT_status"

# Install post-commit hook (stores assertion hashes as git notes after commit)
install_hook "post-commit" "post-commit-hook.sh" "IIKIT-POST-COMMIT"
POST_HOOK_INSTALLED="$RESULT_installed"
POST_HOOK_STATUS="$RESULT_status"

# Commit constitution if requested and it exists
CONSTITUTION_COMMITTED=false
if [ "$COMMIT_CONSTITUTION" = true ] && [ -f "$PROJECT_ROOT/CONSTITUTION.md" ]; then
    cd "$PROJECT_ROOT"
    git add CONSTITUTION.md
    # Also add README if it exists
    if [ -f "$PROJECT_ROOT/README.md" ]; then
        git add README.md
    fi
    # Check if there's anything to commit
    if ! git diff --cached --quiet 2>/dev/null; then
        git commit -m "Initialize intent-integrity-kit project with constitution" >/dev/null 2>&1
        CONSTITUTION_COMMITTED=true
    fi
fi

report_hook_status() {
    local hook_name="$1"
    local status="$2"
    case "$status" in
        installed)
            echo "[specify] $hook_name hook installed"
            ;;
        updated)
            echo "[specify] $hook_name hook updated"
            ;;
        installed_alongside)
            echo "[specify] $hook_name hook installed alongside existing hook"
            ;;
        source_not_found)
            echo "[specify] Warning: $hook_name hook source not found — skipped installation" >&2
            ;;
    esac
}

if $JSON_MODE; then
    printf '{"success":true,"git_initialized":%s,"git_status":"%s","constitution_committed":%s,"hook_installed":%s,"hook_status":"%s","post_hook_installed":%s,"post_hook_status":"%s","project_root":"%s"}\n' \
        "$GIT_INITIALIZED" "$GIT_STATUS" "$CONSTITUTION_COMMITTED" "$HOOK_INSTALLED" "$HOOK_STATUS" "$POST_HOOK_INSTALLED" "$POST_HOOK_STATUS" "$PROJECT_ROOT"
else
    if [ "$GIT_INITIALIZED" = true ]; then
        echo "[specify] Git repository initialized at $PROJECT_ROOT"
    else
        echo "[specify] Git repository already exists at $PROJECT_ROOT"
    fi
    if [ "$CONSTITUTION_COMMITTED" = true ]; then
        echo "[specify] Constitution committed to git"
    fi
    report_hook_status "Pre-commit" "$HOOK_STATUS"
    report_hook_status "Post-commit" "$POST_HOOK_STATUS"
fi
