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

# Check if already a git repo. `--is-inside-work-tree` is true for linked
# worktrees and submodules (where `.git` is a file pointing at the real
# gitdir), so it covers all the layouts `-d .git` misses.
if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_INITIALIZED=false
    GIT_STATUS="already_initialized"
else
    # Initialize git
    git init "$PROJECT_ROOT" >/dev/null 2>&1
    GIT_INITIALIZED=true
    GIT_STATUS="initialized"
fi

# Resolve hooks directory via `git rev-parse --git-path hooks` once and reuse
# everywhere. In a linked worktree or submodule this resolves to the gitdir's
# hooks/ (typically the main repo's `.git/hooks/`), so install_hook and
# pre-commit.d/ provisioning land in the same place git actually runs hooks
# from.
HOOKS_REL="$(git -C "$PROJECT_ROOT" rev-parse --git-path hooks 2>/dev/null)"
case "$HOOKS_REL" in
    /*) HOOKS_ABS="$HOOKS_REL" ;;
    "") HOOKS_ABS="" ;;
    *)  HOOKS_ABS="$PROJECT_ROOT/$HOOKS_REL" ;;
esac

# Check if git user identity is configured (required for commits)
GIT_USER_CONFIGURED=true
if ! git -C "$PROJECT_ROOT" config user.email >/dev/null 2>&1; then
    GIT_USER_CONFIGURED=false
fi
if ! git -C "$PROJECT_ROOT" config user.name >/dev/null 2>&1; then
    GIT_USER_CONFIGURED=false
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

    if [ -z "$HOOKS_ABS" ]; then
        return
    fi

    SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local hook_source="$SCRIPT_DIR/$source_file"

    if [ ! -f "$hook_source" ]; then
        RESULT_status="source_not_found"
        return
    fi

    local hooks_dir="$HOOKS_ABS"
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

# Provision pre-commit.d/ extension point (user-supplied formatters, linters, etc.)
# Uses the same resolved `$HOOKS_ABS` as `install_hook` above so the extension
# point and the hook itself land in the same git-managed hooks directory —
# `git rev-parse --git-path hooks` resolves correctly for linked worktrees
# and submodules where `.git` is a file rather than a directory.
PRECOMMIT_D_PROVISIONED=false
if [ -n "$HOOKS_ABS" ]; then
    PRECOMMIT_D_DIR="$HOOKS_ABS/pre-commit.d"
    mkdir -p "$PRECOMMIT_D_DIR"
    PRECOMMIT_D_README="$PRECOMMIT_D_DIR/README"
    if [ ! -f "$PRECOMMIT_D_README" ]; then
        cat > "$PRECOMMIT_D_README" <<'README_EOF'
# IIKit pre-commit extension point — IIKIT-PRE-COMMIT-D
#
# Drop executable scripts in this directory to extend the pre-commit chain
# without removing or disabling IIKit's pre-commit enforcement (which lives
# at .git/hooks/pre-commit by default, or .git/hooks/iikit-pre-commit when
# IIKit was installed alongside an existing user hook).
#
# Each executable in this dir runs BEFORE IIKit's assertion-integrity check,
# so IIKit remains the final gate — mutating a .feature file / test-specs.md
# / context.json from an extension will be caught by the subsequent IIKit
# check against the post-extension staged state. Files are executed in
# deterministic byte-collation order (LC_ALL=C sort); if one fails the rest
# in this dir still run, but the hook exits non-zero after the loop and
# IIKit does not run. Subdirectories, non-executable files, dotfiles,
# and this README are ignored.
#
# Examples:
#   prettier-write   - bunx prettier --write on staged JS/TS files
#   eslint-fix       - eslint --fix on staged sources
#   secret-scan      - gitleaks protect --staged
#
# Each script receives no arguments. Use `git diff --cached --name-only` to
# find staged files. Exit non-zero to block the commit.
#
# Note: this directory is per-clone (not tracked in git). To share extensions
# across the team, commit your scripts under a tracked path (e.g.
# scripts/git-hooks/) and symlink each into .git/hooks/pre-commit.d/
# during onboarding.
README_EOF
        PRECOMMIT_D_PROVISIONED=true
    fi
fi

# Commit constitution if requested and it exists
CONSTITUTION_COMMITTED=false
if [ "$COMMIT_CONSTITUTION" = true ] && [ -f "$PROJECT_ROOT/CONSTITUTION.md" ]; then
    cd "$PROJECT_ROOT"
    git add CONSTITUTION.md
    # Also add PREMISE.md and README if they exist
    if [ -f "$PROJECT_ROOT/PREMISE.md" ]; then
        git add PREMISE.md
    fi
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
    printf '{"success":true,"git_initialized":%s,"git_status":"%s","git_user_configured":%s,"constitution_committed":%s,"hook_installed":%s,"hook_status":"%s","post_hook_installed":%s,"post_hook_status":"%s","pre_commit_d_provisioned":%s,"project_root":"%s"}\n' \
        "$GIT_INITIALIZED" "$GIT_STATUS" "$GIT_USER_CONFIGURED" "$CONSTITUTION_COMMITTED" "$HOOK_INSTALLED" "$HOOK_STATUS" "$POST_HOOK_INSTALLED" "$POST_HOOK_STATUS" "$PRECOMMIT_D_PROVISIONED" "$PROJECT_ROOT"
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
    if [ "$PRECOMMIT_D_PROVISIONED" = true ]; then
        # Report the resolved path — in worktrees/submodules this differs from
        # `.git/hooks/pre-commit.d/` (the hooks dir lives in the main repo /
        # `.git/modules/<name>/hooks/`).
        DISPLAY_PATH="${PRECOMMIT_D_DIR#"$PROJECT_ROOT/"}"
        echo "[specify] Extension point created at $DISPLAY_PATH (drop user-supplied hooks here)"
    fi
fi
