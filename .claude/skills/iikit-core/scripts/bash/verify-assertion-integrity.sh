#!/usr/bin/env bash
# verify-assertion-integrity.sh — CI-callable assertion integrity verification
#
# Verifies that .feature file assertion hashes match stored hashes in context.json.
# Designed to run in any CI system (GitHub Actions, GitLab CI, Jenkins, etc.)
# as a server-side enforcement layer that cannot be bypassed by --no-verify.
#
# Usage:
#   ./verify-assertion-integrity.sh [--json] [--project-root PATH]
#
# Exit codes:
#   0 — All assertions verified (or no assertions found)
#   1 — Assertion integrity check failed (hash mismatch)
#   2 — Missing dependencies (jq, shasum)
#
# Requires: bash 3.2+, jq, shasum

set -euo pipefail

# Source shared functions by calling testify-tdd.sh compute-hash to verify it works,
# then define the functions we need by extracting them from the script.
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# extract_assertions and compute_assertion_hash are defined in testify-tdd.sh.
# We source the function definitions by evaluating only the function blocks.
eval "$(sed -n '/^extract_assertions()/,/^}/p' "$SCRIPT_DIR/testify-tdd.sh")"
eval "$(sed -n '/^compute_assertion_hash()/,/^}/p' "$SCRIPT_DIR/testify-tdd.sh")"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

JSON_MODE=false
PROJECT_ROOT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true; shift ;;
        --project-root) PROJECT_ROOT="$2"; shift 2 ;;
        --help|-h)
            cat <<'EOF'
Usage: verify-assertion-integrity.sh [--json] [--project-root PATH]

Verifies .feature file assertion hashes against stored hashes in context.json.
Server-side enforcement that cannot be bypassed by --no-verify.

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

for cmd in jq shasum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Required command '$cmd' not found" >&2
        exit 2
    fi
done

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
    if [[ ! -f "$CONTEXT_FILE" ]]; then
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        continue
    fi

    CONTEXT_JSON=$(cat "$CONTEXT_FILE" 2>/dev/null)
    if ! echo "$CONTEXT_JSON" | jq empty 2>/dev/null; then
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        continue
    fi

    STORED_HASH=$(echo "$CONTEXT_JSON" | jq -r '.testify.assertion_hash // ""' 2>/dev/null || echo "")
    STORED_DIR=$(echo "$CONTEXT_JSON" | jq -r '.testify.features_dir // ""' 2>/dev/null || echo "")

    if [[ -z "$STORED_HASH" ]] || [[ -z "$STORED_DIR" ]]; then
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        continue
    fi

    # Compare hashes
    if [[ "$STORED_HASH" == "$CURRENT_HASH" ]]; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        FAILURES+=("$feat_name: expected=$STORED_HASH actual=$CURRENT_HASH")
    fi
done

# =============================================================================
# OUTPUT
# =============================================================================

if $JSON_MODE; then
    STATUS="pass"
    [[ "$TOTAL_FAILED" -gt 0 ]] && STATUS="fail"

    FAILURES_JSON="[]"
    if [[ ${#FAILURES[@]} -gt 0 ]]; then
        FAILURES_JSON=$(printf '"%s",' "${FAILURES[@]}")
        FAILURES_JSON="[${FAILURES_JSON%,}]"
    fi

    printf '{"status":"%s","features_checked":%d,"passed":%d,"failed":%d,"skipped":%d,"failures":%s}\n' \
        "$STATUS" "$TOTAL_CHECKED" "$TOTAL_PASSED" "$TOTAL_FAILED" "$TOTAL_SKIPPED" "$FAILURES_JSON"
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
        echo "  This may indicate a --no-verify bypass of the pre-commit hook."
        echo ""
    fi
fi

if [[ "$TOTAL_FAILED" -gt 0 ]]; then
    exit 1
fi

exit 0
