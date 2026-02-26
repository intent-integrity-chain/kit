#!/usr/bin/env bash
# Generate the static dashboard HTML (idempotent, never fails)
#
# Usage: ./generate-dashboard-safe.sh [project-path]
#
# Replaces ensure-dashboard.sh — no process management, no pidfiles, no ports.
# Just generates .specify/dashboard.html and optionally opens it.

PROJECT_DIR="${1:-$(pwd)}"
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="$PROJECT_DIR/.specify/dashboard.html"

# Find the dashboard generator — may be relative to this script (dev layout)
# or in a sibling skill (published layout where each skill is self-contained)
GENERATOR=""
CANDIDATE_DIRS=(
    "$SCRIPT_DIR/../dashboard"
    "$SCRIPT_DIR/../../../iikit-core/scripts/dashboard"
)
for dir in "${CANDIDATE_DIRS[@]}"; do
    if [[ -f "$dir/src/generate-dashboard.js" ]]; then
        GENERATOR="$dir/src/generate-dashboard.js"
        break
    fi
done

# Skip when called indirectly from BATS tests (via check-prerequisites.sh)
# Direct invocation from BATS tests can override with IIKIT_DASHBOARD_FORCE=1
if [[ -n "${BATS_TEST_FILENAME:-}" || -n "${BATS_TMPDIR:-}" ]] && [[ -z "${IIKIT_DASHBOARD_FORCE:-}" ]]; then
    exit 0
fi

# Check if node is available
if ! command -v node >/dev/null 2>&1; then
    exit 0
fi

# Check if generator was found
if [[ -z "$GENERATOR" ]]; then
    exit 0
fi

# Check if project has CONSTITUTION.md (generator requires it)
if [[ ! -f "$PROJECT_DIR/CONSTITUTION.md" ]]; then
    exit 0
fi

# Generate dashboard — log errors instead of swallowing them
# Note: src/package.json contains {"type":"commonjs"} to prevent Node from treating
# generate-dashboard.js as ESM when the user's project has "type":"module".
DASHBOARD_LOG="$PROJECT_DIR/.specify/dashboard.log"
if node "$GENERATOR" "$PROJECT_DIR" 2>"$DASHBOARD_LOG"; then
    # Success — remove log if empty
    [[ ! -s "$DASHBOARD_LOG" ]] && rm -f "$DASHBOARD_LOG"
else
    # Failed — keep the log for debugging, but don't block the caller
    echo "[iikit] Dashboard generation failed. See $DASHBOARD_LOG" >&2
fi

exit 0
