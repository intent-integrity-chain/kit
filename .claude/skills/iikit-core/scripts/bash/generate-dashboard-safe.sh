#!/usr/bin/env bash
# Generate the static dashboard HTML (idempotent, never fails)
#
# Usage: ./generate-dashboard-safe.sh [project-path]
#
# Replaces ensure-dashboard.sh — no process management, no pidfiles, no ports.
# Just generates .specify/dashboard.html and optionally opens it.

PROJECT_DIR="${1:-$(pwd)}"
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$SCRIPT_DIR/../dashboard"
GENERATOR="$DASHBOARD_DIR/generate-dashboard.js"
OUTPUT_FILE="$PROJECT_DIR/.specify/dashboard.html"

# Skip in test environments
if [[ -n "${BATS_TEST_FILENAME:-}" ]] || [[ -n "${BATS_TMPDIR:-}" ]]; then
    exit 0
fi

# Check if node is available
if ! command -v node >/dev/null 2>&1; then
    exit 0
fi

# Check if generator exists
if [[ ! -f "$GENERATOR" ]]; then
    exit 0
fi

# Check if project has CONSTITUTION.md (generator requires it)
if [[ ! -f "$PROJECT_DIR/CONSTITUTION.md" ]]; then
    exit 0
fi

# Generate dashboard
node "$GENERATOR" "$PROJECT_DIR" 2>/dev/null || exit 0

# Dashboard generated — the skill will suggest the user open it

exit 0
