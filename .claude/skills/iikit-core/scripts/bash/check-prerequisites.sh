#!/usr/bin/env bash

# Phase-aware prerequisite checking script
#
# This script provides unified, phase-driven prerequisite checking for IIKit workflow.
# Each phase declares exactly what it needs (constitution mode, spec, plan, tasks, etc.)
# via a built-in state machine.
#
# Usage: ./check-prerequisites.sh --phase <PHASE> [--json] [--project-root PATH]
#
# PHASES:
#   00       Constitution (no validation)
#   01       Specify (soft constitution)
#   02       Clarify (soft constitution, requires spec)
#   bugfix   Bug fix (soft constitution)
#   03       Plan (hard constitution, requires spec, copies template)
#   04       Checklist (basic constitution, requires spec + plan)
#   05       Testify (basic constitution, requires spec + plan, soft checklist)
#   06       Tasks (basic constitution, requires spec + plan, soft checklist)
#   07       Analyze (hard constitution, requires spec + plan + tasks, soft checklist)
#   08       Implement (hard constitution, requires spec + plan + tasks, hard checklist)
#   09       Tasks to Issues (implicit constitution, requires spec + plan + tasks)
#   core     Paths only (no validation)
#   status   Deterministic status report (non-fatal validation, computes ready_for/next_step)
#
# LEGACY FLAGS (deprecated, map to phases):
#   --paths-only              -> --phase core
#   --require-tasks           -> --phase 08
#   --include-tasks           (used with --require-tasks)
#
# OPTIONS:
#   --json              Output in JSON format
#   --project-root PATH Override project root directory (for testing)
#   --help, -h          Show help message
#
# OUTPUTS (JSON mode):
#   Enriched JSON with phase, paths, validated status, available docs, warnings.
#   Top-level FEATURE_DIR and AVAILABLE_DOCS preserved for backward compat.
#   needs_selection short-circuits all other output (same as before).

set -e

# Parse command line arguments
JSON_MODE=false
PHASE=""
PROJECT_ROOT_ARG=""
LEGACY_PATHS_ONLY=false
LEGACY_REQUIRE_TASKS=false
LEGACY_INCLUDE_TASKS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
            shift
            ;;
        --phase)
            PHASE="$2"
            shift 2
            ;;
        --project-root)
            PROJECT_ROOT_ARG="$2"
            shift 2
            ;;
        --paths-only)
            LEGACY_PATHS_ONLY=true
            shift
            ;;
        --require-tasks)
            LEGACY_REQUIRE_TASKS=true
            shift
            ;;
        --include-tasks)
            LEGACY_INCLUDE_TASKS=true
            shift
            ;;
        --help|-h)
            cat << 'EOF'
Usage: check-prerequisites.sh --phase <PHASE> [--json] [--project-root PATH]

Phase-aware prerequisite checking for IIKit workflow.

PHASES:
  00       Constitution (no validation)
  01       Specify (soft constitution)
  02       Clarify (soft constitution, requires spec)
  bugfix   Bug fix (soft constitution)
  03       Plan (hard constitution, requires spec, copies template)
  04       Checklist (basic constitution, requires spec + plan)
  05       Testify (basic constitution, requires spec + plan, soft checklist)
  06       Tasks (basic constitution, requires spec + plan, soft checklist)
  07       Analyze (hard constitution, requires spec + plan + tasks, soft checklist)
  08       Implement (hard constitution, requires spec + plan + tasks, hard checklist)
  09       Tasks to Issues (implicit constitution, requires spec + plan + tasks)
  core     Paths only (no validation)
  status   Deterministic status report (non-fatal, computes ready_for/next_step)

OPTIONS:
  --json              Output in JSON format
  --project-root PATH Override project root directory (for testing)
  --help, -h          Show this help message

LEGACY FLAGS (deprecated):
  --paths-only        Use --phase core instead
  --require-tasks     Use --phase 08 instead
  --include-tasks     Use --phase 08 instead

EXAMPLES:
  # Check prerequisites for plan phase
  ./check-prerequisites.sh --phase 03 --json

  # Check prerequisites for implementation phase
  ./check-prerequisites.sh --phase 08 --json

  # Get feature paths only (no validation)
  ./check-prerequisites.sh --phase core --json

EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option '$1'. Use --help for usage information." >&2
            exit 1
            ;;
    esac
done

# Map legacy flags to phase (with deprecation warning to stderr)
if [[ -z "$PHASE" ]]; then
    if $LEGACY_PATHS_ONLY; then
        echo "DEPRECATED: --paths-only is deprecated, use --phase core" >&2
        PHASE="core"
    elif $LEGACY_REQUIRE_TASKS; then
        echo "DEPRECATED: --require-tasks/--include-tasks are deprecated, use --phase 08" >&2
        PHASE="08"
    else
        # Default to phase 04 (backward compat with bare invocations)
        PHASE="04"
    fi
fi

# Source common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# PHASE CONFIGURATION
# =============================================================================
# Sets: P_CONST, P_SPEC, P_PLAN, P_TASKS, P_INCLUDE_TASKS, P_CHECKLIST, P_EXTRAS
#
# P_CONST modes:
#   none     - skip constitution check
#   soft     - warn if missing, continue
#   basic    - error if missing
#   hard     - error if missing, output signals enforcement mode
#   implicit - error if missing, no extra output
#
# P_CHECKLIST modes:
#   none - skip checklist check
#   soft - warn if incomplete
#   hard - warn strongly (must be 100% for implementation)

configure_phase() {
    local phase="$1"
    case "$phase" in
        00)      P_CONST=none;     P_SPEC=no;       P_PLAN=no;       P_TASKS=no;       P_INCLUDE_TASKS=no;  P_CHECKLIST=none; P_EXTRAS="" ;;
        01)      P_CONST=soft;     P_SPEC=no;       P_PLAN=no;       P_TASKS=no;       P_INCLUDE_TASKS=no;  P_CHECKLIST=none; P_EXTRAS="" ;;
        02)      P_CONST=soft;     P_SPEC=required; P_PLAN=no;       P_TASKS=no;       P_INCLUDE_TASKS=no;  P_CHECKLIST=none; P_EXTRAS="" ;;
        bugfix)  P_CONST=soft;     P_SPEC=no;       P_PLAN=no;       P_TASKS=no;       P_INCLUDE_TASKS=no;  P_CHECKLIST=none; P_EXTRAS="" ;;
        03)      P_CONST=hard;     P_SPEC=required; P_PLAN=no;       P_TASKS=no;       P_INCLUDE_TASKS=no;  P_CHECKLIST=none; P_EXTRAS="spec_quality,copy_plan_template" ;;
        04)      P_CONST=basic;    P_SPEC=required; P_PLAN=required; P_TASKS=no;       P_INCLUDE_TASKS=no;  P_CHECKLIST=none; P_EXTRAS="" ;;
        05)      P_CONST=basic;    P_SPEC=required; P_PLAN=required; P_TASKS=no;       P_INCLUDE_TASKS=no;  P_CHECKLIST=soft; P_EXTRAS="" ;;
        06)      P_CONST=basic;    P_SPEC=required; P_PLAN=required; P_TASKS=no;       P_INCLUDE_TASKS=no;  P_CHECKLIST=soft; P_EXTRAS="" ;;
        07)      P_CONST=hard;     P_SPEC=required; P_PLAN=required; P_TASKS=required; P_INCLUDE_TASKS=yes; P_CHECKLIST=soft; P_EXTRAS="" ;;
        08)      P_CONST=hard;     P_SPEC=required; P_PLAN=required; P_TASKS=required; P_INCLUDE_TASKS=yes; P_CHECKLIST=hard; P_EXTRAS="" ;;
        09)      P_CONST=implicit; P_SPEC=required; P_PLAN=required; P_TASKS=required; P_INCLUDE_TASKS=yes; P_CHECKLIST=none; P_EXTRAS="" ;;
        core)    P_CONST=none;     P_SPEC=no;       P_PLAN=no;       P_TASKS=no;       P_INCLUDE_TASKS=no;  P_CHECKLIST=none; P_EXTRAS="paths_only" ;;
        status)  P_CONST=none;     P_SPEC=no;       P_PLAN=no;       P_TASKS=no;       P_INCLUDE_TASKS=no;  P_CHECKLIST=none; P_EXTRAS="status_mode" ;;
        *)
            echo "ERROR: Unknown phase '$phase'. Valid: 00 01 02 03 04 05 06 07 08 09 bugfix core status" >&2
            exit 1
            ;;
    esac
}

configure_phase "$PHASE"

# Legacy --include-tasks override (for backward compat when used without --require-tasks)
if $LEGACY_INCLUDE_TASKS && [[ "$P_INCLUDE_TASKS" == "no" ]]; then
    P_INCLUDE_TASKS="yes"
fi

# =============================================================================
# FEATURE DETECTION
# =============================================================================

# Get project root
if [[ -n "$PROJECT_ROOT_ARG" ]]; then
    REPO_ROOT="$PROJECT_ROOT_ARG"
else
    REPO_ROOT=$(get_repo_root)
fi
HAS_GIT="false"
has_git && HAS_GIT="true"
CURRENT_BRANCH=$(get_current_branch)

# Check feature branch (may set SPECIFY_FEATURE, may exit 2 for needs_selection)
STATUS_NO_FEATURE=false
BRANCH_EXIT=0
check_feature_branch "$CURRENT_BRANCH" "$HAS_GIT" || BRANCH_EXIT=$?
if [[ $BRANCH_EXIT -eq 2 ]]; then
    # Multiple features, no active one — caller should present picker
    FEATURES_JSON=$(list_features_json)
    if $JSON_MODE; then
        printf '{"needs_selection":true,"features":%s}\n' "$FEATURES_JSON"
    else
        echo "NEEDS_SELECTION: true"
        echo "Run: /iikit-core use <feature> to select a feature."
    fi
    exit 2
elif [[ $BRANCH_EXIT -ne 0 ]]; then
    if [[ "$P_EXTRAS" == *"status_mode"* ]]; then
        # Status mode: no feature branch is informational, not fatal
        FEATURE_DIR=""
        FEATURE_SPEC=""
        IMPL_PLAN=""
        TASKS=""
        RESEARCH=""
        DATA_MODEL=""
        QUICKSTART=""
        CONTRACTS_DIR=""
        STATUS_NO_FEATURE=true
    else
        exit 1
    fi
fi

# Get all feature paths (uses SPECIFY_FEATURE if set by check_feature_branch)
if ! $STATUS_NO_FEATURE; then
    eval $(get_feature_paths)

    # Override paths if --project-root was specified
    if [[ -n "$PROJECT_ROOT_ARG" ]]; then
        REPO_ROOT="$PROJECT_ROOT_ARG"
        FEATURE_DIR=$(find_feature_dir_by_prefix "$REPO_ROOT" "$CURRENT_BRANCH")
        FEATURE_SPEC="$FEATURE_DIR/spec.md"
        IMPL_PLAN="$FEATURE_DIR/plan.md"
        TASKS="$FEATURE_DIR/tasks.md"
        RESEARCH="$FEATURE_DIR/research.md"
        DATA_MODEL="$FEATURE_DIR/data-model.md"
        QUICKSTART="$FEATURE_DIR/quickstart.md"
        CONTRACTS_DIR="$FEATURE_DIR/contracts"
    fi
fi

# =============================================================================
# PATHS-ONLY SHORT CIRCUIT (core phase)
# =============================================================================

if [[ "$P_EXTRAS" == *"paths_only"* ]]; then
    if $JSON_MODE; then
        printf '{"phase":"%s","constitution_mode":"%s","REPO_ROOT":"%s","BRANCH":"%s","HAS_GIT":%s,"FEATURE_DIR":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s","AVAILABLE_DOCS":[],"validated":{"constitution":false,"spec":false,"plan":false,"tasks":false},"warnings":[]}\n' \
            "$PHASE" "$P_CONST" "$REPO_ROOT" "$CURRENT_BRANCH" "$HAS_GIT" "$FEATURE_DIR" "$FEATURE_SPEC" "$IMPL_PLAN" "$TASKS"
    else
        echo "REPO_ROOT: $REPO_ROOT"
        echo "BRANCH: $CURRENT_BRANCH"
        echo "FEATURE_DIR: $FEATURE_DIR"
        echo "FEATURE_SPEC: $FEATURE_SPEC"
        echo "IMPL_PLAN: $IMPL_PLAN"
        echo "TASKS: $TASKS"
    fi
    # Launch dashboard (idempotent, never fails)
    bash "$SCRIPT_DIR/generate-dashboard-safe.sh"
    exit 0
fi

# =============================================================================
# STATUS MODE (deterministic status report)
# =============================================================================

if [[ "$P_EXTRAS" == *"status_mode"* ]]; then
    # --- Artifact existence checks ---
    A_CONSTITUTION=false
    A_PREMISE=false
    A_SPEC=false
    A_PLAN=false
    A_TASKS=false
    A_CHECKLISTS=false
    A_TEST_SPECS=false

    [[ -f "$REPO_ROOT/CONSTITUTION.md" ]] && A_CONSTITUTION=true
    [[ -f "$REPO_ROOT/PREMISE.md" ]] && A_PREMISE=true
    [[ -n "$FEATURE_DIR" && -f "$FEATURE_DIR/spec.md" ]] && A_SPEC=true
    [[ -n "$FEATURE_DIR" && -f "$FEATURE_DIR/plan.md" ]] && A_PLAN=true
    [[ -n "$FEATURE_DIR" && -f "$FEATURE_DIR/tasks.md" ]] && A_TASKS=true
    [[ -n "$FEATURE_DIR" && -d "$FEATURE_DIR/checklists" ]] && A_CHECKLISTS=true
    [[ -n "$FEATURE_DIR" && -f "$FEATURE_DIR/tests/test-specs.md" ]] && A_TEST_SPECS=true

    # --- Non-fatal validation ---
    V_CONSTITUTION=false
    V_SPEC=false
    V_PLAN=false
    V_TASKS=false
    WARNINGS=()

    if $A_CONSTITUTION; then
        validate_constitution "$REPO_ROOT" 2>/dev/null && V_CONSTITUTION=true || V_CONSTITUTION=false
    fi
    if $A_SPEC; then
        validate_spec "$FEATURE_SPEC" 2>/dev/null && V_SPEC=true || V_SPEC=false
    fi
    if $A_PLAN; then
        validate_plan "$IMPL_PLAN" 2>/dev/null && V_PLAN=true || V_PLAN=false
    fi
    if $A_TASKS; then
        validate_tasks "$TASKS" 2>/dev/null && V_TASKS=true || V_TASKS=false
    fi

    # --- Spec quality (non-fatal) ---
    SPEC_QUALITY=0
    if $A_SPEC; then
        SPEC_QUALITY=$(calculate_spec_quality "$FEATURE_SPEC" 2>/dev/null) || SPEC_QUALITY=0
    fi

    # --- Checklist counting ---
    CHECKLIST_CHECKED=0
    CHECKLIST_TOTAL=0
    CHECKLIST_COMPLETE=false
    if $A_CHECKLISTS; then
        for f in "$FEATURE_DIR/checklists/"*.md; do
            [[ -f "$f" ]] || continue
            while IFS= read -r line; do
                if [[ "$line" =~ ^-\ \[.\] ]]; then
                    CHECKLIST_TOTAL=$((CHECKLIST_TOTAL + 1))
                    if [[ "$line" =~ ^-\ \[[xX]\] ]]; then
                        CHECKLIST_CHECKED=$((CHECKLIST_CHECKED + 1))
                    fi
                fi
            done < "$f"
        done
        if [[ "$CHECKLIST_TOTAL" -gt 0 && "$CHECKLIST_CHECKED" -eq "$CHECKLIST_TOTAL" ]]; then
            CHECKLIST_COMPLETE=true
        fi
    fi

    # --- Feature stage ---
    FEATURE_STAGE="unknown"
    if [[ -n "$FEATURE_DIR" && -d "$FEATURE_DIR" ]]; then
        local_feature=$(basename "$FEATURE_DIR")
        FEATURE_STAGE=$(get_feature_stage "$REPO_ROOT" "$local_feature")
    elif $STATUS_NO_FEATURE; then
        FEATURE_STAGE="no-feature"
    fi

    # --- Ready-for computation (walk phases in order) ---
    # Each phase requires certain artifacts to be valid
    READY_FOR="00"
    # Phase 00: constitution (no prereqs)
    # Phase 01: specify (soft constitution) — always passable
    $V_CONSTITUTION || true  # 01 only needs soft constitution
    READY_FOR="01"
    # Phase 02: clarify (requires valid spec)
    if $V_SPEC; then
        READY_FOR="02"
    fi
    # Phase 03: plan (requires valid spec + hard constitution)
    if $V_CONSTITUTION && $V_SPEC; then
        READY_FOR="03"
    fi
    # Phase 04: checklist (requires valid spec + plan)
    if $V_CONSTITUTION && $V_SPEC && $V_PLAN; then
        READY_FOR="04"
    fi
    # Phase 05: testify (requires valid spec + plan, soft checklist)
    if $V_CONSTITUTION && $V_SPEC && $V_PLAN; then
        READY_FOR="05"
    fi
    # Phase 06: tasks (requires valid spec + plan, soft checklist)
    if $V_CONSTITUTION && $V_SPEC && $V_PLAN; then
        READY_FOR="06"
    fi
    # Phase 07: analyze (requires valid spec + plan + tasks)
    if $V_CONSTITUTION && $V_SPEC && $V_PLAN && $V_TASKS; then
        READY_FOR="07"
    fi
    # Phase 08: implement (requires valid spec + plan + tasks, hard checklist)
    if $V_CONSTITUTION && $V_SPEC && $V_PLAN && $V_TASKS; then
        READY_FOR="08"
    fi
    # Phase 09: tasks to issues (requires valid spec + plan + tasks)
    if $V_CONSTITUTION && $V_SPEC && $V_PLAN && $V_TASKS; then
        READY_FOR="09"
    fi

    # --- Next step + clear_before (deterministic) ---
    NEXT_STEP=""
    CLEAR_BEFORE=false
    if ! $A_CONSTITUTION; then
        NEXT_STEP="/iikit-00-constitution"
        CLEAR_BEFORE=false
    elif $STATUS_NO_FEATURE || [[ -z "$FEATURE_DIR" ]] || [[ ! -d "$FEATURE_DIR" ]]; then
        NEXT_STEP="/iikit-01-specify <description>"
        CLEAR_BEFORE=false
    elif ! $V_SPEC; then
        NEXT_STEP="/iikit-01-specify <description>"
        CLEAR_BEFORE=false
    elif ! $V_PLAN; then
        NEXT_STEP="/iikit-03-plan"
        CLEAR_BEFORE=true
    elif $A_CHECKLISTS && [[ "$CHECKLIST_TOTAL" -gt 0 ]] && ! $CHECKLIST_COMPLETE; then
        NEXT_STEP="/iikit-04-checklist"
        CLEAR_BEFORE=false
    elif ! $V_TASKS; then
        NEXT_STEP="/iikit-06-tasks"
        CLEAR_BEFORE=true
    elif [[ "$FEATURE_STAGE" == "complete" ]]; then
        NEXT_STEP=""
        CLEAR_BEFORE=false
    else
        NEXT_STEP="/iikit-08-implement"
        CLEAR_BEFORE=true
    fi

    # --- Available docs ---
    docs=()
    if [[ -n "$FEATURE_DIR" ]]; then
        [[ -f "$FEATURE_DIR/research.md" ]] && docs+=("research.md")
        [[ -f "$FEATURE_DIR/data-model.md" ]] && docs+=("data-model.md")
        [[ -d "$FEATURE_DIR/contracts" ]] && [[ -n "$(ls -A "$FEATURE_DIR/contracts" 2>/dev/null)" ]] && docs+=("contracts/")
        [[ -f "$FEATURE_DIR/quickstart.md" ]] && docs+=("quickstart.md")
        [[ -f "$TASKS" ]] && docs+=("tasks.md")
    fi

    # --- Output ---
    if $JSON_MODE; then
        # Build JSON docs array
        if [[ ${#docs[@]} -eq 0 ]]; then
            json_docs="[]"
        else
            json_docs=$(printf '"%s",' "${docs[@]}")
            json_docs="[${json_docs%,}]"
        fi

        # Build warnings array
        if [[ ${#WARNINGS[@]} -eq 0 ]]; then
            json_warnings="[]"
        else
            json_warnings=$(printf '"%s",' "${WARNINGS[@]}")
            json_warnings="[${json_warnings%,}]"
        fi

        # Build validated object
        json_validated=$(printf '{"constitution":%s,"spec":%s,"plan":%s,"tasks":%s}' \
            "$V_CONSTITUTION" "$V_SPEC" "$V_PLAN" "$V_TASKS")

        # Build artifacts object
        json_artifacts=$(printf '{"constitution":{"exists":%s,"valid":%s},"premise":{"exists":%s},"spec":{"exists":%s,"valid":%s,"quality":%s},"plan":{"exists":%s,"valid":%s},"tasks":{"exists":%s,"valid":%s},"checklists":{"exists":%s,"checked":%s,"total":%s,"complete":%s},"test_specs":{"exists":%s}}' \
            "$A_CONSTITUTION" "$V_CONSTITUTION" \
            "$A_PREMISE" \
            "$A_SPEC" "$V_SPEC" "$SPEC_QUALITY" \
            "$A_PLAN" "$V_PLAN" \
            "$A_TASKS" "$V_TASKS" \
            "$A_CHECKLISTS" "$CHECKLIST_CHECKED" "$CHECKLIST_TOTAL" "$CHECKLIST_COMPLETE" \
            "$A_TEST_SPECS")

        # Build next_step (null or string)
        if [[ -z "$NEXT_STEP" ]]; then
            json_next_step="null"
        else
            json_next_step="\"$NEXT_STEP\""
        fi

        # Build base JSON
        json_output=$(printf '{"phase":"status","FEATURE_DIR":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s","BRANCH":"%s","HAS_GIT":%s,"REPO_ROOT":"%s","AVAILABLE_DOCS":%s,"validated":%s,"warnings":%s,"artifacts":%s,"feature_stage":"%s","ready_for":"%s","next_step":%s,"clear_before":%s,"checklist_checked":%s,"checklist_total":%s}' \
            "$FEATURE_DIR" "$FEATURE_SPEC" "$IMPL_PLAN" "$TASKS" "$CURRENT_BRANCH" "$HAS_GIT" "$REPO_ROOT" \
            "$json_docs" "$json_validated" "$json_warnings" "$json_artifacts" \
            "$FEATURE_STAGE" "$READY_FOR" "$json_next_step" "$CLEAR_BEFORE" \
            "$CHECKLIST_CHECKED" "$CHECKLIST_TOTAL")

        printf '%s\n' "$json_output"
    else
        echo "Phase: status"
        echo "Feature stage: $FEATURE_STAGE"
        echo "Ready for: phase $READY_FOR"
        if [[ -n "$NEXT_STEP" ]]; then
            if $CLEAR_BEFORE; then
                echo "Next step: /clear, then $NEXT_STEP"
            else
                echo "Next step: $NEXT_STEP"
            fi
        else
            echo "Next step: (none - feature complete)"
        fi
        echo ""
        echo "Artifacts:"
        echo "  Constitution: $(if $A_CONSTITUTION; then echo "[Y]"; else echo "[N]"; fi) $(if $V_CONSTITUTION; then echo "(valid)"; elif $A_CONSTITUTION; then echo "(invalid)"; fi)"
        echo "  Premise:      $(if $A_PREMISE; then echo "[Y]"; else echo "[N]"; fi)"
        echo "  Spec:         $(if $A_SPEC; then echo "[Y]"; else echo "[N]"; fi) $(if $V_SPEC; then echo "(valid, quality $SPEC_QUALITY/10)"; elif $A_SPEC; then echo "(invalid)"; fi)"
        echo "  Plan:         $(if $A_PLAN; then echo "[Y]"; else echo "[N]"; fi) $(if $V_PLAN; then echo "(valid)"; elif $A_PLAN; then echo "(invalid)"; fi)"
        echo "  Tasks:        $(if $A_TASKS; then echo "[Y]"; else echo "[N]"; fi) $(if $V_TASKS; then echo "(valid)"; elif $A_TASKS; then echo "(invalid)"; fi)"
        echo "  Checklists:   $(if $A_CHECKLISTS; then echo "[Y] ($CHECKLIST_CHECKED/$CHECKLIST_TOTAL)"; else echo "[N]"; fi)"
        echo "  Test specs:   $(if $A_TEST_SPECS; then echo "[Y]"; else echo "[N]"; fi)"
    fi

    # Launch dashboard (idempotent, never fails)
    bash "$SCRIPT_DIR/generate-dashboard-safe.sh"
    exit 0
fi

# =============================================================================
# VALIDATION
# =============================================================================

WARNINGS=()
V_CONSTITUTION=false
V_SPEC=false
V_PLAN=false
V_TASKS=false

# Feature directory check (needed for any validation phase)
if [[ ! -d "$FEATURE_DIR" ]]; then
    echo "ERROR: Feature directory not found: $FEATURE_DIR" >&2
    echo "Run /iikit-01-specify first to create the feature structure." >&2
    exit 1
fi

# Constitution validation (per mode)
case "$P_CONST" in
    none)
        # Skip
        ;;
    soft)
        if [[ -f "$REPO_ROOT/CONSTITUTION.md" ]]; then
            V_CONSTITUTION=true
            # Check for completeness
            if ! grep -q "^## .*Principles\|^# .*Constitution" "$REPO_ROOT/CONSTITUTION.md" 2>/dev/null; then
                WARNINGS+=("Constitution may be incomplete - missing principles section")
            fi
        else
            WARNINGS+=("Constitution not found; recommended: /iikit-00-constitution")
        fi
        ;;
    basic|hard|implicit)
        validate_constitution "$REPO_ROOT" || exit 1
        V_CONSTITUTION=true
        ;;
esac

# Spec validation
if [[ "$P_SPEC" == "required" ]]; then
    validate_spec "$FEATURE_SPEC" || exit 1
    V_SPEC=true
fi

# Phase 03 extras: spec quality
SPEC_QUALITY=""
if [[ "$P_EXTRAS" == *"spec_quality"* ]]; then
    SPEC_QUALITY=$(calculate_spec_quality "$FEATURE_SPEC")
    echo "Spec quality score: $SPEC_QUALITY/10" >&2
    if [[ $SPEC_QUALITY -lt 6 ]]; then
        WARNINGS+=("Spec quality is low ($SPEC_QUALITY/10). Consider running /iikit-02-clarify.")
    fi
fi

# Plan validation
if [[ "$P_PLAN" == "required" ]]; then
    validate_plan "$IMPL_PLAN" || exit 1
    V_PLAN=true
fi

# Phase 03 extras: copy plan template
PLAN_TEMPLATE_COPIED=""
if [[ "$P_EXTRAS" == *"copy_plan_template"* ]]; then
    mkdir -p "$FEATURE_DIR"
    TEMPLATE="$SCRIPT_DIR/../../templates/plan-template.md"
    if [[ -f "$TEMPLATE" ]]; then
        cp "$TEMPLATE" "$IMPL_PLAN"
        echo "Copied plan template to $IMPL_PLAN" >&2
        PLAN_TEMPLATE_COPIED=true
    else
        WARNINGS+=("Plan template not found at $TEMPLATE")
        touch "$IMPL_PLAN"
        PLAN_TEMPLATE_COPIED=false
    fi
fi

# Tasks validation
if [[ "$P_TASKS" == "required" ]]; then
    validate_tasks "$TASKS" || exit 1
    V_TASKS=true
fi

# Checklist gate
CHECKLIST_CHECKED=0
CHECKLIST_TOTAL=0
if [[ "$P_CHECKLIST" != "none" ]]; then
    checklists_dir="$FEATURE_DIR/checklists"
    if [[ -d "$checklists_dir" ]]; then
        for f in "$checklists_dir"/*.md; do
            [[ -f "$f" ]] || continue
            while IFS= read -r line; do
                if [[ "$line" =~ ^-\ \[.\] ]]; then
                    CHECKLIST_TOTAL=$((CHECKLIST_TOTAL + 1))
                    if [[ "$line" =~ ^-\ \[[xX]\] ]]; then
                        CHECKLIST_CHECKED=$((CHECKLIST_CHECKED + 1))
                    fi
                fi
            done < "$f"
        done
    fi

    if [[ "$CHECKLIST_TOTAL" -gt 0 && "$CHECKLIST_CHECKED" -lt "$CHECKLIST_TOTAL" ]]; then
        checklist_pct=$(( (CHECKLIST_CHECKED * 100) / CHECKLIST_TOTAL ))
        if [[ "$P_CHECKLIST" == "hard" ]]; then
            WARNINGS+=("Checklists incomplete ($CHECKLIST_CHECKED/$CHECKLIST_TOTAL items, ${checklist_pct}%). Must be 100% for implementation.")
        else
            WARNINGS+=("Checklists incomplete ($CHECKLIST_CHECKED/$CHECKLIST_TOTAL items, ${checklist_pct}%). Recommend /iikit-04-checklist.")
        fi
    fi
fi

# Testify gate — when TDD is mandatory, phases 06+ require .feature files or test-specs.md
if [[ "$PHASE" == "06" || "$PHASE" == "07" || "$PHASE" == "08" || "$PHASE" == "09" ]]; then
    # Source testify-tdd.sh for get_tdd_determination (it sources common.sh)
    source "$SCRIPT_DIR/testify-tdd.sh"
    CONSTITUTION_FILE="$REPO_ROOT/CONSTITUTION.md"
    if [[ -f "$CONSTITUTION_FILE" ]]; then
        TDD_DET=$(get_tdd_determination "$CONSTITUTION_FILE")
        if [[ "$TDD_DET" == "mandatory" ]]; then
            HAS_FEATURES=false
            HAS_TEST_SPECS=false
            if [[ -d "$FEATURE_DIR/tests/features" ]]; then
                FCOUNT=$(find "$FEATURE_DIR/tests/features" -maxdepth 1 -name "*.feature" -type f 2>/dev/null | wc -l | tr -d ' ')
                [[ "$FCOUNT" -gt 0 ]] && HAS_FEATURES=true
            fi
            [[ -f "$FEATURE_DIR/tests/test-specs.md" ]] && HAS_TEST_SPECS=true

            if ! $HAS_FEATURES && ! $HAS_TEST_SPECS; then
                echo "ERROR: TDD is mandatory (per CONSTITUTION.md) but /iikit-05-testify has not been run." >&2
                echo "  No .feature files or test-specs.md found in $FEATURE_DIR/tests/" >&2
                echo "  Run /iikit-05-testify before /iikit-$(printf '%02d' "$PHASE")-*" >&2
                exit 1
            fi
        fi
    fi
fi

# =============================================================================
# BUILD AVAILABLE DOCS
# =============================================================================

docs=()

# Always check these optional docs
[[ -f "$RESEARCH" ]] && docs+=("research.md")
[[ -f "$DATA_MODEL" ]] && docs+=("data-model.md")

# Check contracts directory (only if it exists and has files)
if [[ -d "$CONTRACTS_DIR" ]] && [[ -n "$(ls -A "$CONTRACTS_DIR" 2>/dev/null)" ]]; then
    docs+=("contracts/")
fi

[[ -f "$QUICKSTART" ]] && docs+=("quickstart.md")

# Include tasks.md if phase requires it and it exists
if [[ "$P_INCLUDE_TASKS" == "yes" ]] && [[ -f "$TASKS" ]]; then
    docs+=("tasks.md")
fi

# =============================================================================
# OUTPUT
# =============================================================================

if $JSON_MODE; then
    # Build JSON docs array
    if [[ ${#docs[@]} -eq 0 ]]; then
        json_docs="[]"
    else
        json_docs=$(printf '"%s",' "${docs[@]}")
        json_docs="[${json_docs%,}]"
    fi

    # Build warnings array
    if [[ ${#WARNINGS[@]} -eq 0 ]]; then
        json_warnings="[]"
    else
        json_warnings=$(printf '"%s",' "${WARNINGS[@]}")
        json_warnings="[${json_warnings%,}]"
    fi

    # Build validated object
    json_validated=$(printf '{"constitution":%s,"spec":%s,"plan":%s,"tasks":%s}' \
        "$V_CONSTITUTION" "$V_SPEC" "$V_PLAN" "$V_TASKS")

    # Build base JSON
    json_output=$(printf '{"phase":"%s","constitution_mode":"%s","FEATURE_DIR":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s","BRANCH":"%s","HAS_GIT":%s,"REPO_ROOT":"%s","AVAILABLE_DOCS":%s,"validated":%s,"warnings":%s' \
        "$PHASE" "$P_CONST" "$FEATURE_DIR" "$FEATURE_SPEC" "$IMPL_PLAN" "$TASKS" "$CURRENT_BRANCH" "$HAS_GIT" "$REPO_ROOT" "$json_docs" "$json_validated" "$json_warnings")

    # Phase 03 extras
    if [[ -n "$SPEC_QUALITY" ]]; then
        json_output+=$(printf ',"spec_quality":%s' "$SPEC_QUALITY")
    fi
    if [[ -n "$PLAN_TEMPLATE_COPIED" ]]; then
        json_output+=$(printf ',"plan_template_copied":%s' "$PLAN_TEMPLATE_COPIED")
    fi

    # Checklist info (when gate is active and checklists exist)
    if [[ "$P_CHECKLIST" != "none" && "$CHECKLIST_TOTAL" -gt 0 ]]; then
        json_output+=$(printf ',"checklist_checked":%s,"checklist_total":%s' "$CHECKLIST_CHECKED" "$CHECKLIST_TOTAL")
    fi

    json_output+='}'
    printf '%s\n' "$json_output"
else
    # Text output
    echo "Phase: $PHASE"
    echo "FEATURE_DIR:$FEATURE_DIR"
    echo "AVAILABLE_DOCS:"

    # Show status of each potential document
    check_file "$RESEARCH" "research.md"
    check_file "$DATA_MODEL" "data-model.md"
    check_dir "$CONTRACTS_DIR" "contracts/"
    check_file "$QUICKSTART" "quickstart.md"

    if [[ "$P_INCLUDE_TASKS" == "yes" ]]; then
        check_file "$TASKS" "tasks.md"
    fi

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo ""
        echo "WARNINGS:"
        for w in "${WARNINGS[@]}"; do
            echo "  - $w"
        done
    fi

    if [[ -n "$SPEC_QUALITY" ]]; then
        echo "Spec quality score: $SPEC_QUALITY/10"
    fi
fi

# Launch dashboard (idempotent, never fails)
bash "$SCRIPT_DIR/generate-dashboard-safe.sh"
