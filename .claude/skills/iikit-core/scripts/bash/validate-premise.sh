#!/usr/bin/env bash
# Validate PREMISE.md exists and has all required sections with real content.
# Usage: validate-premise.sh [--json] [project-path]
#
# Required sections: What, Who, Why, Domain, Scope
# Fails if any section is missing, empty, or contains [PLACEHOLDER] tokens.
#
# Exit codes:
#   0 - PASS (all sections present and filled)
#   1 - FAIL (missing file, missing sections, placeholders, or empty sections)

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

JSON_OUTPUT=false
PROJECT_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_OUTPUT=true; shift ;;
        --help|-h)
            cat <<'USAGE'
Usage: validate-premise.sh [--json] [project-path]

Validates PREMISE.md exists at project root and contains all 5 required
sections (What, Who, Why, Domain, Scope) with non-placeholder content.

Options:
  --json          Output results as JSON
  project-path    Path to project root (default: git repo root)

Exit codes:
  0  PASS - all sections present and filled
  1  FAIL - missing file, missing sections, placeholders, or empty sections
USAGE
            exit 0
            ;;
        *)
            if [[ -z "$PROJECT_PATH" ]]; then
                PROJECT_PATH="$1"
            fi
            shift
            ;;
    esac
done

# Determine project root
if [[ -n "$PROJECT_PATH" ]]; then
    REPO_ROOT="$PROJECT_PATH"
else
    REPO_ROOT="$(get_repo_root)"
fi

PREMISE_FILE="$REPO_ROOT/PREMISE.md"

# =============================================================================
# REQUIRED SECTIONS
# =============================================================================

REQUIRED_SECTIONS=("What" "Who" "Why" "Domain" "Scope")

# =============================================================================
# VALIDATION
# =============================================================================

status="PASS"
missing_sections=()
empty_sections=()
details=()
placeholders_remaining=0
sections_found=0

# Check file existence
if [[ ! -f "$PREMISE_FILE" ]]; then
    status="FAIL"
    details+=("PREMISE.md not found at $PREMISE_FILE")

    if $JSON_OUTPUT; then
        printf '{"status":"FAIL","sections_found":0,"sections_required":%d,"placeholders_remaining":0,"missing_sections":[%s],"details":[%s]}\n' \
            "${#REQUIRED_SECTIONS[@]}" \
            "$(printf '"%s",' "${REQUIRED_SECTIONS[@]}" | sed 's/,$//')" \
            "$(printf '"%s",' "${details[@]}" | sed 's/,$//')"
    else
        echo "FAIL: PREMISE.md not found at $PREMISE_FILE" >&2
        echo "Run /iikit-core init to create one." >&2
    fi
    exit 1
fi

# Read file content
premise_content=$(cat "$PREMISE_FILE")

# Check for placeholder tokens: match [WORD] patterns (brackets with uppercase/underscore content)
placeholders_remaining=0
while IFS= read -r line; do
    # Count bracket placeholders like [PROJECT_NAME], [PLACEHOLDER], etc.
    # Match patterns like [WORD] or [MULTI_WORD] but not markdown links [text](url)
    # or checkbox markers [x] [ ]
    matches=$(echo "$line" | grep -oE '\[[A-Z][A-Z_]*\]' 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
        count=$(echo "$matches" | wc -l | tr -d ' ')
        placeholders_remaining=$((placeholders_remaining + count))
    fi
done < "$PREMISE_FILE"

if [[ "$placeholders_remaining" -gt 0 ]]; then
    status="FAIL"
    details+=("Found $placeholders_remaining unresolved placeholder(s)")
fi

# Check each required section
for section in "${REQUIRED_SECTIONS[@]}"; do
    # Look for ## Section heading (case-insensitive)
    if ! grep -qi "^## *${section}" "$PREMISE_FILE" 2>/dev/null; then
        missing_sections+=("$section")
        status="FAIL"
        details+=("Missing required section: $section")
        continue
    fi

    sections_found=$((sections_found + 1))

    # Check for content after the section heading
    # Extract content between this heading and the next heading (or EOF)
    section_content=$(awk -v sect="$section" '
        BEGIN { found=0; IGNORECASE=1 }
        /^## / {
            if (found) exit
            if (tolower($0) ~ "^## *" tolower(sect)) found=1
            next
        }
        found { print }
    ' "$PREMISE_FILE")

    # Filter out empty lines and comment-only lines (<!-- ... -->)
    # Use intermediate variable to avoid pipefail exit on empty grep
    filtered_content=$(echo "$section_content" | grep -v '^\s*$' 2>/dev/null || true)
    filtered_content=$(echo "$filtered_content" | grep -v '^\s*<!--.*-->\s*$' 2>/dev/null || true)
    non_comment_lines=$(echo "$filtered_content" | grep -c '.' 2>/dev/null || true)
    non_comment_lines=${non_comment_lines:-0}

    if [[ "$non_comment_lines" -lt 1 ]]; then
        empty_sections+=("$section")
        status="FAIL"
        details+=("Section '$section' has no content (only comments or blank lines)")
    fi
done

if [[ ${#missing_sections[@]} -gt 0 ]]; then
    details+=("Missing sections: ${missing_sections[*]}")
fi

# =============================================================================
# OUTPUT
# =============================================================================

if $JSON_OUTPUT; then
    # Build JSON output
    missing_json="[]"
    if [[ ${#missing_sections[@]} -gt 0 ]]; then
        missing_json="[$(printf '"%s",' "${missing_sections[@]}" | sed 's/,$//')]"
    fi

    empty_json="[]"
    if [[ ${#empty_sections[@]} -gt 0 ]]; then
        empty_json="[$(printf '"%s",' "${empty_sections[@]}" | sed 's/,$//')]"
    fi

    details_json="[]"
    if [[ ${#details[@]} -gt 0 ]]; then
        details_json="[$(printf '"%s",' "${details[@]}" | sed 's/,$//')]"
    fi

    printf '{"status":"%s","sections_found":%d,"sections_required":%d,"placeholders_remaining":%d,"missing_sections":%s,"empty_sections":%s,"details":%s}\n' \
        "$status" \
        "$sections_found" \
        "${#REQUIRED_SECTIONS[@]}" \
        "$placeholders_remaining" \
        "$missing_json" \
        "$empty_json" \
        "$details_json"
else
    if [[ "$status" == "PASS" ]]; then
        echo "PASS: PREMISE.md is valid ($sections_found/${#REQUIRED_SECTIONS[@]} sections, 0 placeholders)"
    else
        echo "FAIL: PREMISE.md validation failed" >&2
        for detail in "${details[@]}"; do
            echo "  - $detail" >&2
        done
    fi
fi

# Exit with appropriate code
if [[ "$status" == "PASS" ]]; then
    exit 0
else
    exit 1
fi
