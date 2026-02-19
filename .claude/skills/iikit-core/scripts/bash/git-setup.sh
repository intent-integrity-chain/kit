#!/usr/bin/env bash

# Detect git/GitHub environment for IIKit project initialization
# Usage: git-setup.sh [--json]
# Pure probe — no mutations. Returns environment state as JSON or plain text.

set -e

JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--json]"
            echo ""
            echo "Detect git and GitHub environment for IIKit project initialization."
            echo ""
            echo "Options:"
            echo "  --json       Output in JSON format"
            echo "  --help, -h   Show this help message"
            echo ""
            echo "Output fields:"
            echo "  git_available      Whether git is installed"
            echo "  is_git_repo        Whether cwd is inside a git repository"
            echo "  has_remote         Whether a remote (origin) is configured"
            echo "  remote_url         The origin remote URL (empty if none)"
            echo "  is_github_remote   Whether the remote URL points to GitHub"
            echo "  gh_available       Whether the gh CLI is installed"
            echo "  gh_authenticated   Whether gh is authenticated"
            echo "  has_iikit_artifacts Whether .specify or CONSTITUTION.md exists"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# --- Probe git ---
GIT_AVAILABLE=false
if command -v git >/dev/null 2>&1; then
    GIT_AVAILABLE=true
fi

IS_GIT_REPO=false
if [ "$GIT_AVAILABLE" = true ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    IS_GIT_REPO=true
fi

# --- Probe remote ---
HAS_REMOTE=false
REMOTE_URL=""
IS_GITHUB_REMOTE=false

if [ "$IS_GIT_REPO" = true ]; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
    if [ -n "$REMOTE_URL" ]; then
        HAS_REMOTE=true
        case "$REMOTE_URL" in
            *github.com*) IS_GITHUB_REMOTE=true ;;
        esac
    fi
fi

# --- Probe gh CLI ---
GH_AVAILABLE=false
if command -v gh >/dev/null 2>&1; then
    GH_AVAILABLE=true
fi

GH_AUTHENTICATED=false
if [ "$GH_AVAILABLE" = true ] && gh auth status >/dev/null 2>&1; then
    GH_AUTHENTICATED=true
fi

# --- Probe IIKit artifacts ---
HAS_IIKIT_ARTIFACTS=false
if [ -d ".specify" ] || [ -f "CONSTITUTION.md" ]; then
    HAS_IIKIT_ARTIFACTS=true
fi

# --- Output ---
if $JSON_MODE; then
    # Escape remote_url for JSON (handle special characters)
    ESCAPED_URL=$(printf '%s' "$REMOTE_URL" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '{"git_available":%s,"is_git_repo":%s,"has_remote":%s,"remote_url":"%s","is_github_remote":%s,"gh_available":%s,"gh_authenticated":%s,"has_iikit_artifacts":%s}\n' \
        "$GIT_AVAILABLE" "$IS_GIT_REPO" "$HAS_REMOTE" "$ESCAPED_URL" "$IS_GITHUB_REMOTE" "$GH_AVAILABLE" "$GH_AUTHENTICATED" "$HAS_IIKIT_ARTIFACTS"
else
    echo "Git available:       $GIT_AVAILABLE"
    echo "Is git repo:         $IS_GIT_REPO"
    echo "Has remote:          $HAS_REMOTE"
    echo "Remote URL:          ${REMOTE_URL:-(none)}"
    echo "Is GitHub remote:    $IS_GITHUB_REMOTE"
    echo "gh CLI available:    $GH_AVAILABLE"
    echo "gh authenticated:    $GH_AUTHENTICATED"
    echo "Has IIKit artifacts: $HAS_IIKIT_ARTIFACTS"
fi
