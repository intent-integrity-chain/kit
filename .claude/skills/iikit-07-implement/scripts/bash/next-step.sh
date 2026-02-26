#!/usr/bin/env bash
# next-step.sh — Single source of truth for IIKit next-step determination
#
# Usage:
#   bash next-step.sh --phase <completed_phase> --json [--project-root PATH]
#
# --phase values: 00, 01, 02, 03, 04, 05, 06, 07, 08, clarify, bugfix, core, status
# --json: (required) output JSON
# --project-root: optional, defaults to git root
#
# Mandatory path: 00 → 01 → 02 → [04 if TDD] → 05 → 07
# Optional steps: 03 (checklist), 06 (analyze), 08 (tasks-to-issues)
#
# Two modes:
#   Phase-based: given a completed phase, return the deterministic next step
#   Artifact-state fallback: scan disk artifacts to determine where we are

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

PHASE=""
JSON_MODE=false
PROJECT_ROOT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase)   PHASE="$2"; shift 2 ;;
        --json)    JSON_MODE=true; shift ;;
        --project-root) PROJECT_ROOT="$2"; shift 2 ;;
        *)         echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$PHASE" ]]; then
    echo "Error: --phase is required" >&2
    exit 1
fi

if ! $JSON_MODE; then
    echo "Error: --json is required" >&2
    exit 1
fi

# =============================================================================
# PROJECT DETECTION
# =============================================================================

if [[ -n "$PROJECT_ROOT" ]]; then
    REPO_ROOT="$PROJECT_ROOT"
else
    REPO_ROOT=$(get_repo_root 2>/dev/null) || { echo '{"error":"Cannot determine project root"}'; exit 1; }
fi

# =============================================================================
# FEATURE DETECTION
# =============================================================================

FEATURE=""
FEATURE=$(read_active_feature "$REPO_ROOT" 2>/dev/null) || true
FEATURE_DIR=""
[[ -n "$FEATURE" ]] && FEATURE_DIR="$REPO_ROOT/specs/$FEATURE"

# =============================================================================
# ARTIFACT EXISTENCE
# =============================================================================

A_CONSTITUTION=false
A_SPEC=false
A_PLAN=false
A_TASKS=false
A_CHECKLISTS=false
A_TEST_SPECS=false
A_ANALYSIS=false

[[ -f "$REPO_ROOT/CONSTITUTION.md" ]] && A_CONSTITUTION=true

if [[ -n "$FEATURE_DIR" && -d "$FEATURE_DIR" ]]; then
    [[ -f "$FEATURE_DIR/spec.md" ]] && A_SPEC=true
    [[ -f "$FEATURE_DIR/plan.md" ]] && A_PLAN=true
    [[ -f "$FEATURE_DIR/tasks.md" ]] && A_TASKS=true
    [[ -d "$FEATURE_DIR/checklists" ]] && [[ -n "$(ls -A "$FEATURE_DIR/checklists" 2>/dev/null)" ]] && A_CHECKLISTS=true
    [[ -f "$FEATURE_DIR/tests/test-specs.md" ]] && A_TEST_SPECS=true
    # Also check for .feature files in tests/features/
    if [[ -d "$FEATURE_DIR/tests/features" ]] && [[ -n "$(ls "$FEATURE_DIR/tests/features/"*.feature 2>/dev/null)" ]]; then
        A_TEST_SPECS=true
    fi
    [[ -f "$FEATURE_DIR/analysis.md" ]] && A_ANALYSIS=true
fi

# =============================================================================
# TDD DETERMINATION
# =============================================================================

TDD_MANDATORY=false
TDD_STATUS=$(get_cached_tdd_determination "$REPO_ROOT" 2>/dev/null) || TDD_STATUS="unknown"
[[ "$TDD_STATUS" == "mandatory" ]] && TDD_MANDATORY=true

# =============================================================================
# FEATURE STAGE
# =============================================================================

FEATURE_STAGE="unknown"
if [[ -n "$FEATURE" ]]; then
    FEATURE_STAGE=$(get_feature_stage "$REPO_ROOT" "$FEATURE")
fi

# =============================================================================
# CHECKLIST STATUS
# =============================================================================

CHECKLIST_COMPLETE=false
if $A_CHECKLISTS && [[ -n "$FEATURE_DIR" ]]; then
    local_total=0
    local_checked=0
    for cl_file in "$FEATURE_DIR/checklists/"*.md; do
        [[ -f "$cl_file" ]] || continue
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*-\ \[.\] ]]; then
                local_total=$((local_total + 1))
                if [[ "$line" =~ ^[[:space:]]*-\ \[[xX]\] ]]; then
                    local_checked=$((local_checked + 1))
                fi
            fi
        done < "$cl_file"
    done
    [[ "$local_total" -gt 0 && "$local_checked" -eq "$local_total" ]] && CHECKLIST_COMPLETE=true
fi

# =============================================================================
# MODEL TIER LOOKUP
# =============================================================================

get_model_tier() {
    local phase="$1"
    case "$phase" in
        core|03|08)              echo "light" ;;
        01|clarify|04|05|bugfix) echo "medium" ;;
        00|02|06|07)             echo "heavy" ;;
        status)                  echo "light" ;;
        "")                      echo "" ;;
        *)                       echo "medium" ;;
    esac
}

# =============================================================================
# CLEAR LOGIC
#
# clear_after:  heavy context consumed by the COMPLETED phase — suggest /clear
# clear_before: the NEXT phase benefits from fresh context — suggest /clear
# =============================================================================

get_clear_after() {
    local completed="$1"
    case "$completed" in
        02)      echo true ;;   # Plan consumed context
        03)      echo true ;;   # Interactive checklist consumed context
        07)      echo true ;;   # Implementation consumed massive context
        clarify) echo true ;;   # Q&A consumed context
        *)       echo false ;;
    esac
}

get_clear_before() {
    local next="$1"
    case "$next" in
        02) echo true ;;   # Plan is heavy
        05) echo true ;;   # Tasks generation benefits from fresh context
        06) echo true ;;   # Analyze is heavy
        07) echo true ;;   # Implement is heavy
        *)  echo false ;;
    esac
}

# =============================================================================
# BUILD ALT STEPS
# =============================================================================

# Outputs a JSON array of alternative steps
build_alt_steps() {
    local completed="$1"
    local next_phase="$2"
    local alts=""

    # /iikit-clarify is always an option when any artifact exists
    if $A_CONSTITUTION || $A_SPEC || $A_PLAN || $A_TASKS; then
        alts="${alts}{\"step\":\"/iikit-clarify\",\"reason\":\"Resolve ambiguities\",\"model_tier\":\"medium\"},"
    fi

    # Phase-specific alternatives
    case "$completed" in
        00)
            # After constitution: no extra alts beyond clarify
            ;;
        01)
            # After specify: suggest constitution if missing
            if ! $A_CONSTITUTION; then
                alts="${alts}{\"step\":\"/iikit-00-constitution\",\"reason\":\"Define project governance\",\"model_tier\":\"heavy\"},"
            fi
            ;;
        02)
            # After plan: checklist is optional, testify is optional if TDD not mandatory
            alts="${alts}{\"step\":\"/iikit-03-checklist\",\"reason\":\"Optional quality checklist\",\"model_tier\":\"light\"},"
            if ! $TDD_MANDATORY; then
                alts="${alts}{\"step\":\"/iikit-04-testify\",\"reason\":\"Optional test specifications\",\"model_tier\":\"medium\"},"
            fi
            ;;
        03)
            # After checklist: testify is optional if TDD not mandatory
            if ! $TDD_MANDATORY; then
                alts="${alts}{\"step\":\"/iikit-04-testify\",\"reason\":\"Optional test specifications\",\"model_tier\":\"medium\"},"
            fi
            ;;
        05)
            # After tasks: analyze is optional
            alts="${alts}{\"step\":\"/iikit-06-analyze\",\"reason\":\"Optional consistency analysis\",\"model_tier\":\"heavy\"},"
            ;;
        07)
            # After implement: tasks-to-issues is optional
            if [[ "$FEATURE_STAGE" == "complete" ]]; then
                alts="${alts}{\"step\":\"/iikit-08-taskstoissues\",\"reason\":\"Export tasks to GitHub Issues\",\"model_tier\":\"light\"},"
            fi
            ;;
        clarify|core|status)
            # Build phase-specific alts based on artifact state
            if $A_PLAN && ! $A_TASKS; then
                # After plan: same alts as phase 02
                alts="${alts}{\"step\":\"/iikit-03-checklist\",\"reason\":\"Optional quality checklist\",\"model_tier\":\"light\"},"
                if ! $TDD_MANDATORY; then
                    alts="${alts}{\"step\":\"/iikit-04-testify\",\"reason\":\"Optional test specifications\",\"model_tier\":\"medium\"},"
                fi
            elif $A_TASKS; then
                # After tasks: same alts as phase 05
                alts="${alts}{\"step\":\"/iikit-06-analyze\",\"reason\":\"Optional consistency analysis\",\"model_tier\":\"heavy\"},"
                if [[ "$FEATURE_STAGE" == "complete" ]]; then
                    alts="${alts}{\"step\":\"/iikit-08-taskstoissues\",\"reason\":\"Export tasks to GitHub Issues\",\"model_tier\":\"light\"},"
                fi
            fi
            ;;
    esac

    # Strip trailing comma and wrap in array
    alts="${alts%,}"
    if [[ -n "$alts" ]]; then
        echo "[$alts]"
    else
        echo "[]"
    fi
}

# =============================================================================
# ARTIFACT-STATE FALLBACK
#
# When we don't have a clear "just completed phase X" signal (e.g., after
# clarify, core, status, or edge cases), scan artifacts to determine position.
# This is reconstructible from disk — no context.json dependency.
# =============================================================================

artifact_state_fallback() {
    local next_step=""
    local next_phase=""

    if ! $A_CONSTITUTION; then
        next_step="/iikit-00-constitution"
        next_phase="00"
    elif [[ -z "$FEATURE" ]] || [[ ! -d "$FEATURE_DIR" ]] || ! $A_SPEC; then
        next_step="/iikit-01-specify"
        next_phase="01"
    elif ! $A_PLAN; then
        next_step="/iikit-02-plan"
        next_phase="02"
    elif $TDD_MANDATORY && ! $A_TEST_SPECS; then
        next_step="/iikit-04-testify"
        next_phase="04"
    elif ! $A_TASKS; then
        next_step="/iikit-05-tasks"
        next_phase="05"
    elif [[ "$FEATURE_STAGE" == "complete" ]]; then
        next_step=""
        next_phase=""
    else
        next_step="/iikit-07-implement"
        next_phase="07"
    fi

    echo "$next_step|$next_phase"
}

# =============================================================================
# PHASE-BASED STATE MACHINE
#
# Given a completed phase, determine the next step deterministically.
# Mandatory path: 00 → 01 → 02 → [04 if TDD] → 05 → 07
# =============================================================================

compute_next_step() {
    local completed="$1"
    local next_step=""
    local next_phase=""

    case "$completed" in
        00)
            next_step="/iikit-01-specify"
            next_phase="01"
            ;;
        01)
            next_step="/iikit-02-plan"
            next_phase="02"
            ;;
        02)
            if $TDD_MANDATORY; then
                next_step="/iikit-04-testify"
                next_phase="04"
            else
                next_step="/iikit-05-tasks"
                next_phase="05"
            fi
            ;;
        03)
            # Checklist is optional; after it, continue on the mandatory path
            if $TDD_MANDATORY && ! $A_TEST_SPECS; then
                next_step="/iikit-04-testify"
                next_phase="04"
            else
                next_step="/iikit-05-tasks"
                next_phase="05"
            fi
            ;;
        04)
            next_step="/iikit-05-tasks"
            next_phase="05"
            ;;
        05)
            next_step="/iikit-07-implement"
            next_phase="07"
            ;;
        06)
            # Analyze is optional; after it, proceed to implement
            next_step="/iikit-07-implement"
            next_phase="07"
            ;;
        07)
            if [[ "$FEATURE_STAGE" == "complete" ]]; then
                next_step=""
                next_phase=""
            else
                # Feature incomplete — resume implementation
                next_step="/iikit-07-implement"
                next_phase="07"
            fi
            ;;
        08)
            # Terminal — workflow complete
            next_step=""
            next_phase=""
            ;;
        bugfix)
            # Bugfix always leads to implement
            next_step="/iikit-07-implement"
            next_phase="07"
            ;;
        clarify|core|status)
            # Use artifact-state fallback
            local fallback
            fallback=$(artifact_state_fallback)
            next_step="${fallback%%|*}"
            next_phase="${fallback##*|}"
            ;;
        *)
            # Unknown phase — use fallback
            local fallback
            fallback=$(artifact_state_fallback)
            next_step="${fallback%%|*}"
            next_phase="${fallback##*|}"
            ;;
    esac

    echo "$next_step|$next_phase"
}

# =============================================================================
# MAIN
# =============================================================================

# Compute next step
RESULT=$(compute_next_step "$PHASE")
NEXT_STEP="${RESULT%%|*}"
NEXT_PHASE="${RESULT##*|}"

# Compute clear flags
CLEAR_AFTER=$(get_clear_after "$PHASE")
CLEAR_BEFORE=$(get_clear_before "$NEXT_PHASE")

# Model tier for the next phase
MODEL_TIER=$(get_model_tier "$NEXT_PHASE")

# Alt steps
ALT_STEPS=$(build_alt_steps "$PHASE" "$NEXT_PHASE")

# Build next_step JSON value (null or string)
if [[ -z "$NEXT_STEP" ]]; then
    JSON_NEXT_STEP="null"
    JSON_NEXT_PHASE="null"
    JSON_MODEL_TIER="null"
else
    JSON_NEXT_STEP="\"$NEXT_STEP\""
    JSON_NEXT_PHASE="\"$NEXT_PHASE\""
    JSON_MODEL_TIER="\"$MODEL_TIER\""
fi

# Output JSON
printf '{"current_phase":"%s","next_step":%s,"next_phase":%s,"clear_before":%s,"clear_after":%s,"model_tier":%s,"feature_stage":"%s","tdd_mandatory":%s,"alt_steps":%s}\n' \
    "$PHASE" \
    "$JSON_NEXT_STEP" \
    "$JSON_NEXT_PHASE" \
    "$CLEAR_BEFORE" \
    "$CLEAR_AFTER" \
    "$JSON_MODEL_TIER" \
    "$FEATURE_STAGE" \
    "$TDD_MANDATORY" \
    "$ALT_STEPS"
