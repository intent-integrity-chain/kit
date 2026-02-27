#!/usr/bin/env bash
# Verify BDD step coverage by detecting undefined/pending steps via framework dry-run
# Usage: verify-steps.sh [--json] <features-dir> <plan-file>

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# FRAMEWORK DETECTION
# =============================================================================

# Detect BDD framework — uses shared detect_framework from common.sh
# Returns: framework name only (strips language from "framework|language" pair)
# Falls back to file extension heuristics if plan.md detection fails
detect_framework_for_steps() {
    local plan_file="$1"
    local features_dir="$2"

    # Use shared detection from common.sh (returns "framework|language")
    local result
    result=$(detect_framework "$plan_file")
    local framework
    framework=$(echo "$result" | cut -d'|' -f1)

    # Fall back to file extension heuristics if plan.md didn't resolve
    if [[ -z "$framework" ]] && [[ -d "$features_dir" ]]; then
        local parent_dir
        parent_dir=$(dirname "$features_dir")

        if find "$parent_dir" -maxdepth 3 -name "*.py" -type f 2>/dev/null | head -1 | grep -q .; then
            framework="pytest-bdd"
        elif find "$parent_dir" -maxdepth 3 -name "*.ts" -o -name "*.js" -type f 2>/dev/null | head -1 | grep -q .; then
            framework="@cucumber/cucumber"
        elif find "$parent_dir" -maxdepth 3 -name "*.go" -type f 2>/dev/null | head -1 | grep -q .; then
            framework="godog"
        elif find "$parent_dir" -maxdepth 3 -name "*.rs" -type f 2>/dev/null | head -1 | grep -q .; then
            framework="cucumber-rs"
        elif find "$parent_dir" -maxdepth 3 -name "*.cs" -type f 2>/dev/null | head -1 | grep -q .; then
            framework="reqnroll"
        elif find "$parent_dir" -maxdepth 3 -name "*.java" -type f 2>/dev/null | head -1 | grep -q .; then
            framework="cucumber-jvm-maven"
        fi
    fi

    echo "$framework"
}

# Get the dry-run command for a given framework
get_dry_run_command() {
    local framework="$1"
    local features_dir="$2"

    case "$framework" in
        pytest-bdd)
            echo "pytest --collect-only tests/"
            ;;
        behave)
            echo "behave --dry-run --strict"
            ;;
        @cucumber/cucumber)
            echo "npx cucumber-js --dry-run --strict"
            ;;
        godog)
            echo "godog --strict --no-colors --dry-run"
            ;;
        cucumber-jvm-maven)
            echo "mvn test -Dcucumber.options=\"--dry-run --strict\""
            ;;
        cucumber-jvm-gradle)
            echo "gradle test -Dcucumber.options=\"--dry-run --strict\""
            ;;
        cucumber-rs)
            echo "cargo test"
            ;;
        reqnroll)
            echo "dotnet test -e \"REQNROLL_DRY_RUN=true\""
            ;;
        *)
            echo ""
            ;;
    esac
}

# =============================================================================
# STEP COUNTING
# =============================================================================

# Count total steps in .feature files
count_feature_steps() {
    local features_dir="$1"
    local count=0

    if [[ -d "$features_dir" ]]; then
        count=$(grep -rchE "^\s*(Given|When|Then|And|But) " "$features_dir"/*.feature 2>/dev/null | paste -sd+ - | bc 2>/dev/null) || count=0
        # If bc not available or no files found
        if [[ -z "$count" ]]; then
            count=0
        fi
    fi

    echo "$count"
}

# =============================================================================
# DRY-RUN EXECUTION AND PARSING
# =============================================================================

# Execute the framework-specific dry-run command
# Returns raw output for parsing
run_dry_run() {
    local framework="$1"
    local features_dir="$2"
    local dry_run_cmd
    dry_run_cmd=$(get_dry_run_command "$framework" "$features_dir")

    if [[ -z "$dry_run_cmd" ]]; then
        echo ""
        return 1
    fi

    # Execute dry-run, capturing both stdout and stderr
    local output
    output=$(eval "$dry_run_cmd" 2>&1) || true

    echo "$output"
}

# Parse dry-run output for undefined/pending steps
# Returns JSON with step coverage details
parse_results() {
    local framework="$1"
    local output="$2"
    local features_dir="$3"
    local total_steps
    total_steps=$(count_feature_steps "$features_dir")

    local undefined_steps=0
    local pending_steps=0
    local details="[]"

    case "$framework" in
        pytest-bdd)
            # pytest --collect-only shows "no tests ran" or collection errors for undefined steps
            undefined_steps=$(echo "$output" | grep -c "StepDefNotFound\|ERRORS\|no tests ran" 2>/dev/null) || undefined_steps=0
            if echo "$output" | grep -qi "StepDefNotFound\|no tests ran"; then
                # Extract undefined step details
                details=$(echo "$output" | grep -E "StepDefNotFound|ERRORS" | head -20 | while IFS= read -r line; do
                    printf '{"step":"%s","file":"unknown","line":0},' "$(echo "$line" | sed 's/"/\\"/g')"
                done)
                details="[${details%,}]"
            fi
            ;;
        behave)
            # behave --dry-run --strict reports undefined steps
            undefined_steps=$(echo "$output" | grep -c "undefined" 2>/dev/null) || undefined_steps=0
            pending_steps=$(echo "$output" | grep -c "pending\|skipped" 2>/dev/null) || pending_steps=0
            if [[ "$undefined_steps" -gt 0 ]]; then
                details=$(echo "$output" | grep -E "undefined" | head -20 | while IFS= read -r line; do
                    printf '{"step":"%s","file":"unknown","line":0},' "$(echo "$line" | sed 's/"/\\"/g')"
                done)
                details="[${details%,}]"
            fi
            ;;
        @cucumber/cucumber)
            # cucumber-js --dry-run --strict marks undefined steps
            undefined_steps=$(echo "$output" | grep -c "Undefined" 2>/dev/null) || undefined_steps=0
            pending_steps=$(echo "$output" | grep -c "Pending" 2>/dev/null) || pending_steps=0
            if [[ "$undefined_steps" -gt 0 ]]; then
                details=$(echo "$output" | grep -B1 "Undefined" | grep -E "^\s*(Given|When|Then|And|But)" | head -20 | while IFS= read -r line; do
                    local step
                    step=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/"/\\"/g')
                    printf '{"step":"%s","file":"unknown","line":0},' "$step"
                done)
                details="[${details%,}]"
            fi
            ;;
        godog)
            # godog --dry-run --strict reports undefined steps
            undefined_steps=$(echo "$output" | grep -c "undefined" 2>/dev/null) || undefined_steps=0
            pending_steps=$(echo "$output" | grep -c "pending" 2>/dev/null) || pending_steps=0
            ;;
        cucumber-jvm-maven|cucumber-jvm-gradle)
            # Cucumber-JVM reports undefined/pending steps
            undefined_steps=$(echo "$output" | grep -c "Undefined" 2>/dev/null) || undefined_steps=0
            pending_steps=$(echo "$output" | grep -c "Pending" 2>/dev/null) || pending_steps=0
            ;;
        cucumber-rs)
            # cucumber-rs reports skipped steps (which indicate undefined when fail_on_skipped)
            undefined_steps=$(echo "$output" | grep -c "skipped\|undefined" 2>/dev/null) || undefined_steps=0
            ;;
        reqnroll)
            # Reqnroll reports binding errors for undefined steps
            undefined_steps=$(echo "$output" | grep -c "Binding\|StepDefinitionMissing\|undefined" 2>/dev/null) || undefined_steps=0
            ;;
    esac

    # Calculate matched steps
    local matched_steps=$((total_steps - undefined_steps - pending_steps))
    if [[ "$matched_steps" -lt 0 ]]; then
        matched_steps=0
    fi

    # Ensure details is valid JSON
    if [[ -z "$details" ]] || [[ "$details" == "[]" ]]; then
        details="[]"
    fi

    # Determine status
    local status="PASS"
    if [[ "$undefined_steps" -gt 0 ]] || [[ "$pending_steps" -gt 0 ]]; then
        status="BLOCKED"
    fi

    printf '{"status":"%s","framework":"%s","total_steps":%d,"matched_steps":%d,"undefined_steps":%d,"pending_steps":%d,"details":%s}' \
        "$status" "$framework" "$total_steps" "$matched_steps" "$undefined_steps" "$pending_steps" "$details"
}

# =============================================================================
# OUTPUT HELPERS
# =============================================================================

# Output DEGRADED status when no framework detected
output_degraded() {
    local json_mode="$1"
    local message="No BDD framework detected for tech stack. Verification chain is not integral."

    if [[ "$json_mode" == "true" ]]; then
        printf '{"status":"DEGRADED","framework":null,"message":"%s","total_steps":0,"matched_steps":0,"undefined_steps":0,"pending_steps":0,"details":[]}' "$message"
    else
        echo "[verify-steps] DEGRADED: $message"
    fi
}

# Output result in JSON or human-readable format
output_result() {
    local json_mode="$1"
    local result_json="$2"

    if [[ "$json_mode" == "true" ]]; then
        echo "$result_json"
    else
        local status
        local framework
        local total
        local matched
        local undefined
        local pending

        status=$(echo "$result_json" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        framework=$(echo "$result_json" | grep -o '"framework":"[^"]*"' | cut -d'"' -f4)
        total=$(echo "$result_json" | grep -o '"total_steps":[0-9]*' | cut -d: -f2)
        matched=$(echo "$result_json" | grep -o '"matched_steps":[0-9]*' | cut -d: -f2)
        undefined=$(echo "$result_json" | grep -o '"undefined_steps":[0-9]*' | cut -d: -f2)
        pending=$(echo "$result_json" | grep -o '"pending_steps":[0-9]*' | cut -d: -f2)

        echo "[verify-steps] Status: $status"
        echo "[verify-steps] Framework: $framework"
        echo "[verify-steps] Steps: $matched/$total matched, $undefined undefined, $pending pending"

        if [[ "$status" == "BLOCKED" ]]; then
            echo "[verify-steps] WARNING: Undefined or pending steps detected. Step definitions are incomplete."
        fi
    fi
}

# =============================================================================
# MAIN (only runs when script is executed directly, not sourced)
# =============================================================================

# Guard: skip main when sourced (allows tests to source functions directly)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

JSON_MODE=false
[[ "${1:-}" == "--json" ]] && { JSON_MODE=true; shift; }

FEATURES_DIR="${1:?Usage: verify-steps.sh [--json] <features-dir> <plan-file>}"
PLAN_FILE="${2:?Usage: verify-steps.sh [--json] <features-dir> <plan-file>}"

# Validate features directory
if [[ ! -d "$FEATURES_DIR" ]]; then
    if [[ "$JSON_MODE" == "true" ]]; then
        printf '{"status":"DEGRADED","framework":null,"message":"Features directory not found: %s","total_steps":0,"matched_steps":0,"undefined_steps":0,"pending_steps":0,"details":[]}' "$FEATURES_DIR"
    else
        echo "[verify-steps] ERROR: Features directory not found: $FEATURES_DIR" >&2
    fi
    exit 0
fi

# Check for .feature files
feature_count=$(find "$FEATURES_DIR" -maxdepth 1 -name "*.feature" -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ "$feature_count" -eq 0 ]]; then
    if [[ "$JSON_MODE" == "true" ]]; then
        printf '{"status":"DEGRADED","framework":null,"message":"No .feature files found in %s","total_steps":0,"matched_steps":0,"undefined_steps":0,"pending_steps":0,"details":[]}' "$FEATURES_DIR"
    else
        echo "[verify-steps] WARNING: No .feature files found in $FEATURES_DIR" >&2
    fi
    exit 0
fi

# Detect framework
framework=$(detect_framework_for_steps "$PLAN_FILE" "$FEATURES_DIR")

if [[ -z "$framework" ]]; then
    output_degraded "$JSON_MODE"
    exit 0
fi

# Check if dry-run command tool is available
dry_run_cmd=$(get_dry_run_command "$framework" "$FEATURES_DIR")
if [[ -z "$dry_run_cmd" ]]; then
    output_degraded "$JSON_MODE"
    exit 0
fi

# Extract the base command to check availability
base_cmd=$(echo "$dry_run_cmd" | awk '{print $1}')
if ! command -v "$base_cmd" >/dev/null 2>&1; then
    # Tool not installed - return DEGRADED rather than failing
    if [[ "$JSON_MODE" == "true" ]]; then
        printf '{"status":"DEGRADED","framework":"%s","message":"Framework tool not found: %s. Install it to enable step verification.","total_steps":0,"matched_steps":0,"undefined_steps":0,"pending_steps":0,"details":[]}' "$framework" "$base_cmd"
    else
        echo "[verify-steps] DEGRADED: Framework tool not found: $base_cmd" >&2
    fi
    exit 0
fi

# Run dry-run
dry_run_output=$(run_dry_run "$framework" "$FEATURES_DIR")

# Parse results
result_json=$(parse_results "$framework" "$dry_run_output" "$FEATURES_DIR")

# Output
output_result "$JSON_MODE" "$result_json"

# Exit code: 0 for PASS/DEGRADED, 1 for BLOCKED
status=$(echo "$result_json" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [[ "$status" == "BLOCKED" ]]; then
    exit 1
fi
exit 0

fi  # End of main guard
