#!/usr/bin/env bash
# BASH 3.2 REQUIRED — no associative arrays, no mapfile, no |&
#
# Combined BDD verification: verify-steps + verify-step-quality in one call.
# Saves 1 tool call round-trip per task during BDD implementation.
#
# Usage: bash verify-bdd.sh --json <features-dir> <plan-file> <step-defs-dir> <language>
# Output: JSON combining step coverage and step quality results.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

JSON_MODE=false
FEATURES_DIR=""
PLAN_FILE=""
STEP_DEFS_DIR=""
LANGUAGE=""

# Parse args
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        *)
            if [[ -z "$FEATURES_DIR" ]]; then
                FEATURES_DIR="$arg"
            elif [[ -z "$PLAN_FILE" ]]; then
                PLAN_FILE="$arg"
            elif [[ -z "$STEP_DEFS_DIR" ]]; then
                STEP_DEFS_DIR="$arg"
            elif [[ -z "$LANGUAGE" ]]; then
                LANGUAGE="$arg"
            fi
            ;;
    esac
done

if [[ -z "$FEATURES_DIR" || -z "$PLAN_FILE" ]]; then
    echo "Usage: verify-bdd.sh --json <features-dir> <plan-file> <step-defs-dir> <language>" >&2
    exit 1
fi

# Step 1: verify-steps (coverage)
STEPS_JSON=$(bash "$SCRIPT_DIR/verify-steps.sh" --json "$FEATURES_DIR" "$PLAN_FILE" 2>/dev/null | grep '^{' | head -1)
if [[ -z "$STEPS_JSON" ]]; then
    STEPS_JSON='{"status":"ERROR","message":"verify-steps.sh failed"}'
fi

# Step 2: verify-step-quality (only if step defs dir provided and exists)
QUALITY_JSON='{"status":"SKIPPED","message":"no step definitions directory"}'
if [[ -n "$STEP_DEFS_DIR" && -d "$STEP_DEFS_DIR" && -n "$LANGUAGE" ]]; then
    QUALITY_JSON=$(bash "$SCRIPT_DIR/verify-step-quality.sh" --json "$STEP_DEFS_DIR" "$LANGUAGE" 2>/dev/null | grep '^{' | head -1)
    if [[ -z "$QUALITY_JSON" ]]; then
        QUALITY_JSON='{"status":"ERROR","message":"verify-step-quality.sh failed"}'
    fi
fi

# Combine
if $JSON_MODE; then
    printf '{"steps":%s,"quality":%s}\n' "$STEPS_JSON" "$QUALITY_JSON"
else
    echo "=== Step Coverage ==="
    echo "$STEPS_JSON"
    echo ""
    echo "=== Step Quality ==="
    echo "$QUALITY_JSON"
fi
