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
YELLOW='\033[1;33m'
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

    # Run review and capture JSON
    json_output=$(tessl skill review --json "$skill_md" 2>/dev/null)

    if [[ -z "$json_output" ]]; then
        echo -e "${RED}[FAIL]${NC} $skill_name — review returned empty output"
        ((FAILED++))
        BELOW_THRESHOLD+=("$skill_name: empty output")
        continue
    fi

    # Parse scores
    scores=$(echo "$json_output" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    desc = d['descriptionJudge']['normalizedScore']
    cont = d['contentJudge']['normalizedScore']
    avg = (desc + cont) / 2
    print(f'{desc:.4f} {cont:.4f} {avg:.4f}')
except Exception as e:
    print(f'ERROR {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1)

    if [[ $? -ne 0 || "$scores" == ERROR* ]]; then
        echo -e "${RED}[FAIL]${NC} $skill_name — failed to parse scores: $scores"
        ((FAILED++))
        BELOW_THRESHOLD+=("$skill_name: parse error")
        continue
    fi

    read desc_score cont_score avg_score <<< "$scores"

    # Convert to percentage (integer)
    avg_pct=$(python3 -c "print(int(round($avg_score * 100)))")
    desc_pct=$(python3 -c "print(int(round($desc_score * 100)))")
    cont_pct=$(python3 -c "print(int(round($cont_score * 100)))")

    if [[ "$avg_pct" -ge "$THRESHOLD" ]]; then
        echo -e "${GREEN}[PASS]${NC} $skill_name — ${avg_pct}% (desc: ${desc_pct}%, content: ${cont_pct}%)"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} $skill_name — ${avg_pct}% < ${THRESHOLD}% (desc: ${desc_pct}%, content: ${cont_pct}%)"
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
