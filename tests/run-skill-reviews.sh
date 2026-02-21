#!/usr/bin/env bash
#
# Review all IIKit skills via tessl skill review.
# Fails if any skill's average score drops below the threshold.
#
# Usage:
#   ./tests/run-skill-reviews.sh [--threshold 90]
#

set -uo pipefail

THRESHOLD=90
if [[ "${1:-}" == "--threshold" ]]; then
    THRESHOLD="${2:-90}"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.claude/skills"

TOTAL=0
PASSED=0
FAILED=0
BELOW_THRESHOLD=()

echo ""
echo -e "${BLUE}╔═════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  IIKit Skill Review (threshold: ${THRESHOLD}%)    ║${NC}"
echo -e "${BLUE}╚═════════════════════════════════════════╝${NC}"
echo ""

for skill_dir in "$SKILLS_DIR"/iikit-*/; do
    skill_md="$skill_dir/SKILL.md"
    [[ ! -f "$skill_md" ]] && continue

    skill_name=$(basename "$skill_dir")
    ((TOTAL++))

    # Run review and capture full output (human-readable)
    review_output=$(tessl skill review "$skill_md" 2>&1) || true

    # Parse "Average Score: NN%" from output
    avg_pct=$(echo "$review_output" | sed -n 's/.*Average Score: \([0-9]*\)%.*/\1/p')

    if [[ -z "$avg_pct" ]]; then
        echo -e "${RED}[FAIL]${NC} $skill_name — could not parse score from review output"
        echo "$review_output" | tail -3
        ((FAILED++))
        BELOW_THRESHOLD+=("$skill_name: parse error")
        continue
    fi

    # Parse description and content scores
    desc_pct=$(echo "$review_output" | sed -n 's/.*Description: \([0-9]*\)%.*/\1/p')
    cont_pct=$(echo "$review_output" | sed -n 's/.*Content: \([0-9]*\)%.*/\1/p')

    if [[ "$avg_pct" -ge "$THRESHOLD" ]]; then
        echo -e "${GREEN}[PASS]${NC} $skill_name — ${avg_pct}%${desc_pct:+ (desc: ${desc_pct}%, content: ${cont_pct}%)}"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} $skill_name — ${avg_pct}% < ${THRESHOLD}%${desc_pct:+ (desc: ${desc_pct}%, content: ${cont_pct}%)}"
        ((FAILED++))
        BELOW_THRESHOLD+=("$skill_name: ${avg_pct}%")
    fi
done

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo "  Total:    $TOTAL"
echo -e "  ${GREEN}Passed:   $PASSED${NC}"
echo -e "  ${RED}Failed:   $FAILED${NC}"
echo "  Threshold: ${THRESHOLD}%"

if [[ ${#BELOW_THRESHOLD[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}Skills below threshold:${NC}"
    for item in "${BELOW_THRESHOLD[@]}"; do
        echo "  - $item"
    done
    exit 1
fi

exit 0
