#!/usr/bin/env bash
# verify-assertion-integrity.sh — CI-callable assertion integrity verification
#
# Verifies that .feature file assertion hashes match stored hashes in context.json.
# Designed to run in any CI system (GitHub Actions, GitLab CI, Jenkins, etc.)
# as a server-side enforcement layer that cannot be bypassed client-side.
#
# Usage:
#   ./verify-assertion-integrity.sh [--json] [--project-root PATH]
#
# Exit codes:
#   0 — All assertions verified (or no assertions found)
#   1 — Assertion integrity check failed (hash mismatch or missing hash)
#   2 — Missing dependencies (jq, shasum/sha256sum)
#
# Requires: bash 3.2+, jq, shasum or sha256sum

set -euo pipefail

# Extract function definitions from testify-tdd.sh without executing it.
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Override extract_assertions with POSIX-compatible patterns (\s -> [[:space:]])
# to ensure correct behavior on all grep implementations.
extract_assertions() {
    local input_path="$1"
    if [[ -d "$input_path" ]]; then
        local files
        files=$(ls -1 "$input_path"/*.feature 2>/dev/null | LC_ALL=C sort)
        [[ -z "$files" ]] && { echo ""; return 0; }
        local f
        for f in $files; do
            { grep -E "^[[:space:]]*(Given|When|Then|And|But) " "$f" 2>/dev/null || true; }
        done | sed 's/^[[:space:]]*//' | sed 's/[[:space:]][[:space:]]*/ /g' | sed 's/[[:space:]]*$//'
    elif [[ -f "$input_path" ]]; then
        if [[ "$input_path" == *.feature ]]; then
            { grep -E "^[[:space:]]*(Given|When|Then|And|But) " "$input_path" 2>/dev/null || true; } \
                | sed 's/^[[:space:]]*//' | sed 's/[[:space:]][[:space:]]*/ /g' | sed 's/[[:space:]]*$//'
        else
            { grep -E "^\*\*(Given|When|Then)\*\*:" "$input_path" 2>/dev/null || true; } \
                | sed 's/[[:space:]]*$//' | LC_ALL=C sort
        fi
    else
        echo ""; return 0
    fi
}

# compute_assertion_hash from testify-tdd.sh uses shasum -a 256.
# Override to support sha256sum (Linux) when shasum is not available.
compute_assertion_hash() {
    local input_path="$1"
    local assertions
    assertions=$(extract_assertions "$input_path")
    if [[ -z "$assertions" ]]; then
        echo "NO_ASSERTIONS"
        return
    fi
    if command -v shasum >/dev/null 2>&1; then
        printf '%s' "$assertions" | shasum -a 256 | cut -d' ' -f1
    else
        printf '%s' "$assertions" | sha256sum | cut -d' ' -f1
    fi
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

JSON_MODE=false
PROJECT_ROOT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true; shift ;;
        --project-root)
            if [[ $# -lt 2 ]] || [[ "$2" == --* ]]; then
                echo "ERROR: --project-root requires a path argument" >&2; exit 2
            fi
            PROJECT_ROOT="$2"; shift 2 ;;
        --help|-h)
            cat <<'EOF'
Usage: verify-assertion-integrity.sh [--json] [--project-root PATH]

Verifies .feature file assertion hashes against stored hashes in context.json.
Server-side enforcement that cannot be bypassed client-side.

Options:
  --json              Output results in JSON format
  --project-root PATH Override project root directory
  --help, -h          Show this help message

Exit codes:
  0 — All assertions verified (or no assertions found)
  1 — Assertion integrity check failed
  2 — Missing dependencies
EOF
            exit 0
            ;;
        *) echo "ERROR: Unknown option '$1'" >&2; exit 2 ;;
    esac
done

# =============================================================================
# DEPENDENCY CHECK
# =============================================================================

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: Required command 'jq' not found" >&2
    exit 2
fi

# Support both shasum (macOS) and sha256sum (Linux)
if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
    echo "ERROR: Neither 'shasum' nor 'sha256sum' found" >&2
    exit 2
fi

# =============================================================================
# PROJECT ROOT DETECTION
# =============================================================================

if [[ -z "$PROJECT_ROOT" ]]; then
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        PROJECT_ROOT=$(git rev-parse --show-toplevel)
    else
        PROJECT_ROOT="$(pwd)"
    fi
fi

SPECS_DIR="$PROJECT_ROOT/specs"

if [[ ! -d "$SPECS_DIR" ]]; then
    if $JSON_MODE; then
        printf '{"status":"pass","features_checked":0,"message":"No specs/ directory found"}\n'
    fi
    exit 0
fi

# =============================================================================
# VERIFY ALL FEATURES
# =============================================================================

TOTAL_CHECKED=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
FAILURES=()

for feat_dir in "$SPECS_DIR"/*/; do
    [[ ! -d "$feat_dir" ]] && continue
    feat_name=$(basename "$feat_dir")

    FEATURES_DIR="$feat_dir/tests/features"
    CONTEXT_FILE="$feat_dir/context.json"

    # Skip features without .feature files
    if [[ ! -d "$FEATURES_DIR" ]]; then
        continue
    fi

    FEATURE_COUNT=$(find "$FEATURES_DIR" -maxdepth 1 -name "*.feature" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$FEATURE_COUNT" -eq 0 ]]; then
        continue
    fi

    TOTAL_CHECKED=$((TOTAL_CHECKED + 1))

    # Compute current hash from .feature files on disk
    CURRENT_HASH=$(compute_assertion_hash "$FEATURES_DIR")

    if [[ "$CURRENT_HASH" == "NO_ASSERTIONS" ]]; then
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        continue
    fi

    # Read stored hash from context.json
    # Missing context.json with existing .feature files = integrity failure
    # (prevents bypass via context.json deletion)
    if [[ ! -f "$CONTEXT_FILE" ]]; then
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        FAILURES+=("$feat_name: context.json missing (assertions exist but no stored hash)")
        continue
    fi

    CONTEXT_JSON=$(cat "$CONTEXT_FILE" 2>/dev/null)
    if ! echo "$CONTEXT_JSON" | jq empty 2>/dev/null; then
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        FAILURES+=("$feat_name: context.json is invalid JSON")
        continue
    fi

    STORED_HASH=$(echo "$CONTEXT_JSON" | jq -r '.testify.assertion_hash // ""' 2>/dev/null || echo "")

    if [[ -z "$STORED_HASH" ]]; then
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        FAILURES+=("$feat_name: no assertion hash in context.json (run /iikit-04-testify)")
        continue
    fi

    # Compare hashes
    if [[ "$STORED_HASH" == "$CURRENT_HASH" ]]; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        FAILURES+=("$feat_name: hash mismatch (stored=$STORED_HASH actual=$CURRENT_HASH)")
    fi
done

# =============================================================================
# OUTPUT
# =============================================================================

if $JSON_MODE; then
    STATUS="pass"
    [[ "$TOTAL_FAILED" -gt 0 ]] && STATUS="fail"

    # Build failures array with proper JSON escaping
    if [[ ${#FAILURES[@]} -gt 0 ]]; then
        FAILURES_JSON=$(printf '%s\n' "${FAILURES[@]}" | jq -R . | jq -s .)
    else
        FAILURES_JSON="[]"
    fi

    jq -n \
        --arg status "$STATUS" \
        --argjson checked "$TOTAL_CHECKED" \
        --argjson passed "$TOTAL_PASSED" \
        --argjson failed "$TOTAL_FAILED" \
        --argjson skipped "$TOTAL_SKIPPED" \
        --argjson failures "$FAILURES_JSON" \
        '{status:$status,features_checked:$checked,passed:$passed,failed:$failed,skipped:$skipped,failures:$failures}'
else
    if [[ "$TOTAL_CHECKED" -eq 0 ]]; then
        echo "[iikit] No features with .feature files found — nothing to verify."
        exit 0
    fi

    echo "[iikit] Assertion integrity check: $TOTAL_CHECKED features checked"
    echo "  Passed:  $TOTAL_PASSED"
    echo "  Failed:  $TOTAL_FAILED"
    echo "  Skipped: $TOTAL_SKIPPED"

    if [[ "$TOTAL_FAILED" -gt 0 ]]; then
        echo ""
        echo "+-------------------------------------------------------------+"
        echo "|  ASSERTION INTEGRITY CHECK FAILED                           |"
        echo "+-------------------------------------------------------------+"
        echo ""
        for failure in "${FAILURES[@]}"; do
            echo "  FAILED: $failure"
        done
        echo ""
        echo "  .feature assertions were modified without re-running /iikit-04-testify."
        echo "  This may indicate a hook bypass."
        echo ""
    fi
fi

if [[ "$TOTAL_FAILED" -gt 0 ]]; then
    exit 1
fi

exit 0
