#!/usr/bin/env bash
# BASH 3.2 REQUIRED — no associative arrays, no mapfile, no |&
#
# Post-phase: commit + dashboard + next-step in one call.
# Reduces 3 tool call round-trips to 1.
#
# Usage: bash post-phase.sh --phase NN [--feature-dir PATH] [--commit-files "PATTERNS"] [--commit-msg "MSG"] [--project-root PATH]
# Output: JSON with commit status and next-step data.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

PHASE=""
FEATURE_DIR=""
COMMIT_FILES=""
COMMIT_MSG=""
PROJECT_ROOT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase)        PHASE="$2"; shift 2 ;;
        --feature-dir)  FEATURE_DIR="$2"; shift 2 ;;
        --commit-files) COMMIT_FILES="$2"; shift 2 ;;
        --commit-msg)   COMMIT_MSG="$2"; shift 2 ;;
        --project-root) PROJECT_ROOT="$2"; shift 2 ;;
        *)
            echo "ERROR: Unknown argument '$1'" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$PHASE" ]]; then
    echo "ERROR: --phase is required" >&2
    exit 1
fi

# =============================================================================
# GIT COMMIT
# =============================================================================

COMMITTED=false
if [[ -n "$COMMIT_FILES" ]] && has_git; then
    OLD_IFS="$IFS"
    IFS=','
    for pattern in $COMMIT_FILES; do
        IFS="$OLD_IFS"
        pattern=$(echo "$pattern" | sed 's/^ *//;s/ *$//')
        if [[ "$pattern" == "-u" ]]; then
            git add -u 2>/dev/null || true
        else
            eval git add $pattern 2>/dev/null || true
        fi
    done
    IFS="$OLD_IFS"

    if ! git diff --cached --quiet 2>/dev/null; then
        if [[ -n "$COMMIT_MSG" ]]; then
            git commit -m "$COMMIT_MSG" >/dev/null 2>&1 && COMMITTED=true
        fi
    fi
fi

# =============================================================================
# DASHBOARD REFRESH
# =============================================================================

bash "$SCRIPT_DIR/generate-dashboard-safe.sh" >/dev/null 2>&1 || true

# =============================================================================
# NEXT STEP
# =============================================================================

NEXT_ARGS="--phase $PHASE --json"
if [[ -n "$PROJECT_ROOT" ]]; then
    NEXT_ARGS="$NEXT_ARGS --project-root $PROJECT_ROOT"
fi

NEXT_JSON=$(bash "$SCRIPT_DIR/next-step.sh" $NEXT_ARGS 2>/dev/null | grep '^{' | head -1)
if [[ -z "$NEXT_JSON" ]]; then
    NEXT_JSON="null"
fi

# =============================================================================
# OUTPUT
# =============================================================================

printf '{"committed":%s,"next_step":%s}\n' "$COMMITTED" "$NEXT_JSON"
