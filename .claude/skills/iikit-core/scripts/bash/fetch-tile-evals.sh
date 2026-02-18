#!/usr/bin/env bash
# Fetch Tessl eval results for a tile and save them for dashboard consumption

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# Usage
# =============================================================================

show_help() {
    cat <<'EOF'
Usage: fetch-tile-evals.sh [OPTIONS] <tile-name>

Fetch Tessl eval results for a tile and save to .specify/evals/.

Arguments:
  tile-name    Full tile name (e.g., tessl-labs/some-tile)

Options:
  --json       Output summary as JSON
  --run        Run eval if none found (triggers tessl eval run)
  --help, -h   Show this help message

Examples:
  fetch-tile-evals.sh --json tessl-labs/tile-creator
  fetch-tile-evals.sh --json --run tessl-labs/some-tile
EOF
}

# =============================================================================
# Main
# =============================================================================

JSON_MODE=false
RUN_MODE=false
TILE_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)  JSON_MODE=true; shift ;;
        --run)   RUN_MODE=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        -*) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
        *)  TILE_NAME="$1"; shift ;;
    esac
done

if [[ -z "$TILE_NAME" ]]; then
    echo "ERROR: tile-name argument is required" >&2
    echo "Run with --help for usage." >&2
    exit 1
fi

# Check tessl CLI available — exit 0 silently if not
if ! command -v tessl >/dev/null 2>&1; then
    if $JSON_MODE; then
        echo '{"status":"skipped","reason":"tessl CLI not available"}'
    fi
    exit 0
fi

# Split tile name into workspace and tile
WORKSPACE="${TILE_NAME%%/*}"
TILE="${TILE_NAME#*/}"

if [[ "$WORKSPACE" == "$TILE" ]]; then
    echo "ERROR: tile-name must be in workspace/tile format (e.g., tessl-labs/some-tile)" >&2
    exit 1
fi

REPO_ROOT=$(get_repo_root)
EVALS_DIR="$REPO_ROOT/.specify/evals"
mkdir -p "$EVALS_DIR"

# Sanitize filename: workspace--tile.json
EVAL_FILE="$EVALS_DIR/${WORKSPACE}--${TILE}.json"

# Try to find latest completed eval
EVAL_LIST=$(tessl eval list --json --limit 1 --workspace "$WORKSPACE" --tile "$TILE" 2>/dev/null) || EVAL_LIST=""

# If no evals and --run requested, trigger one
if [[ -z "$EVAL_LIST" || "$EVAL_LIST" == "[]" || "$EVAL_LIST" == "null" ]]; then
    if $RUN_MODE; then
        echo "[specify] No evals found for $TILE_NAME, running eval..." >&2
        tessl eval run --workspace "$WORKSPACE" --tile "$TILE" 2>/dev/null || true
        # Re-fetch after run
        EVAL_LIST=$(tessl eval list --json --limit 1 --workspace "$WORKSPACE" --tile "$TILE" 2>/dev/null) || EVAL_LIST=""
    fi
fi

# If still no evals, report and exit
if [[ -z "$EVAL_LIST" || "$EVAL_LIST" == "[]" || "$EVAL_LIST" == "null" ]]; then
    if $JSON_MODE; then
        echo "{\"tile\":\"$TILE_NAME\",\"status\":\"no_evals\"}"
    else
        echo "[specify] No eval results found for $TILE_NAME" >&2
    fi
    exit 0
fi

# Extract eval ID from list (first result)
EVAL_ID=$(echo "$EVAL_LIST" | jq -r '.[0].id // empty' 2>/dev/null)

if [[ -z "$EVAL_ID" ]]; then
    if $JSON_MODE; then
        echo "{\"tile\":\"$TILE_NAME\",\"status\":\"no_evals\"}"
    else
        echo "[specify] Could not extract eval ID for $TILE_NAME" >&2
    fi
    exit 0
fi

# Fetch full eval results
EVAL_DATA=$(tessl eval view --json "$EVAL_ID" 2>/dev/null) || EVAL_DATA=""

if [[ -z "$EVAL_DATA" ]]; then
    if $JSON_MODE; then
        echo "{\"tile\":\"$TILE_NAME\",\"status\":\"fetch_failed\"}"
    else
        echo "[specify] Failed to fetch eval details for $TILE_NAME (eval $EVAL_ID)" >&2
    fi
    exit 0
fi

# Save full results
echo "$EVAL_DATA" > "$EVAL_FILE"

# Extract summary fields
SCORE=$(echo "$EVAL_DATA" | jq -r '.score // .total_score // 0' 2>/dev/null)
MAX_SCORE=$(echo "$EVAL_DATA" | jq -r '.max_score // 100' 2>/dev/null)
SCENARIOS=$(echo "$EVAL_DATA" | jq -r '.scenarios | length // 0' 2>/dev/null || echo "0")
SCORED_AT=$(echo "$EVAL_DATA" | jq -r '.scored_at // .completed_at // .created_at // "unknown"' 2>/dev/null)

# Calculate percentage
if [[ "$MAX_SCORE" -gt 0 ]] 2>/dev/null; then
    PCT=$(( (SCORE * 100) / MAX_SCORE ))
else
    PCT=0
fi

if $JSON_MODE; then
    cat <<EOF
{"tile":"$TILE_NAME","score":$SCORE,"max_score":$MAX_SCORE,"pct":$PCT,"scenarios":$SCENARIOS,"scored_at":"$SCORED_AT","eval_file":"$EVAL_FILE"}
EOF
else
    echo "[specify] Eval for $TILE_NAME: $SCORE/$MAX_SCORE ($PCT%) — $SCENARIOS scenarios, scored $SCORED_AT"
    echo "[specify] Full results saved to $EVAL_FILE"
fi
