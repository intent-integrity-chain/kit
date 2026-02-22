#!/usr/bin/env bash
# TDD Assessment and Test Generation Helper for Testify Skill
# This script provides utilities for the testify skill

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# TDD ASSESSMENT FUNCTIONS
# =============================================================================

# Assess constitution for TDD requirements
# Returns JSON with determination, confidence, evidence, reasoning
assess_tdd_requirements() {
    local constitution_file="$1"

    if [[ ! -f "$constitution_file" ]]; then
        echo '{"error": "Constitution file not found"}'
        return 1
    fi

    local content
    content=$(cat "$constitution_file")

    # Initialize assessment
    local determination="optional"
    local confidence="high"
    local evidence=""
    local reasoning="No TDD indicators found in constitution"

    # Check for strong TDD indicators with MUST/REQUIRED
    if echo "$content" | grep -qi "MUST.*\(TDD\|test-first\|red-green-refactor\|write tests before\)"; then
        determination="mandatory"
        confidence="high"
        evidence=$(echo "$content" | grep -i "MUST.*\(TDD\|test-first\|red-green-refactor\|write tests before\)" | head -1)
        reasoning="Strong TDD indicator found with MUST modifier"
    elif echo "$content" | grep -qi "\(TDD\|test-first\|red-green-refactor\|write tests before\).*MUST"; then
        determination="mandatory"
        confidence="high"
        evidence=$(echo "$content" | grep -i "\(TDD\|test-first\|red-green-refactor\|write tests before\).*MUST" | head -1)
        reasoning="Strong TDD indicator found with MUST modifier"
    # Check for moderate indicators
    elif echo "$content" | grep -qi "MUST.*\(test-driven\|tests.*before.*code\|tests.*before.*implementation\)"; then
        determination="mandatory"
        confidence="medium"
        evidence=$(echo "$content" | grep -i "MUST.*\(test-driven\|tests.*before.*code\|tests.*before.*implementation\)" | head -1)
        reasoning="Moderate TDD indicator found with MUST modifier"
    # Check for prohibition indicators (both word orders)
    elif echo "$content" | grep -qi "MUST.*\(test-after\|integration tests only\|no unit tests\)"; then
        determination="forbidden"
        confidence="high"
        evidence=$(echo "$content" | grep -i "MUST.*\(test-after\|integration tests only\|no unit tests\)" | head -1)
        reasoning="TDD prohibition indicator found"
    elif echo "$content" | grep -qi "\(test-after\|integration tests only\|no unit tests\).*MUST"; then
        determination="forbidden"
        confidence="high"
        evidence=$(echo "$content" | grep -i "\(test-after\|integration tests only\|no unit tests\).*MUST" | head -1)
        reasoning="TDD prohibition indicator found"
    # Check for implicit indicators (SHOULD)
    elif echo "$content" | grep -qi "SHOULD.*\(quality gates\|coverage\|test\)"; then
        determination="optional"
        confidence="low"
        evidence=$(echo "$content" | grep -i "SHOULD.*\(quality gates\|coverage\|test\)" | head -1)
        reasoning="Implicit testing indicator found with SHOULD modifier"
    fi

    # Output JSON
    cat <<EOF
{
    "determination": "$determination",
    "confidence": "$confidence",
    "evidence": $(echo "$evidence" | jq -Rs .),
    "reasoning": "$reasoning"
}
EOF
}

# =============================================================================
# ASSERTION INTEGRITY FUNCTIONS
# =============================================================================

# Extract assertion content for hashing
# Accepts: directory path (tests/features/), single .feature file, or legacy test-specs.md
# For .feature files: extracts Given/When/Then/And/But step lines in document order
#   - Files sorted by name for determinism, lines in document order within each file
#   - Whitespace normalized: leading stripped, internal collapsed, trailing stripped
# For test-specs.md (legacy): extracts **Given**:/**When**:/**Then**: lines, sorted
extract_assertions() {
    local input_path="$1"

    if [[ -d "$input_path" ]]; then
        # Directory input: glob all .feature files, sorted by name
        # shellcheck disable=SC2012
        local files
        files=$(ls -1 "$input_path"/*.feature 2>/dev/null | LC_ALL=C sort)

        if [[ -z "$files" ]]; then
            echo ""
            return 0
        fi

        # Extract step lines in document order per file, normalize whitespace
        local f
        for f in $files; do
            { grep -E "^\s*(Given|When|Then|And|But) " "$f" 2>/dev/null || true; }
        done | sed 's/^[[:space:]]*//' | sed 's/[[:space:]][[:space:]]*/ /g' | sed 's/[[:space:]]*$//'
    elif [[ -f "$input_path" ]]; then
        if [[ "$input_path" == *.feature ]]; then
            # Single .feature file input
            { grep -E "^\s*(Given|When|Then|And|But) " "$input_path" 2>/dev/null || true; } \
                | sed 's/^[[:space:]]*//' | sed 's/[[:space:]][[:space:]]*/ /g' | sed 's/[[:space:]]*$//'
        else
            # Legacy test-specs.md input: extract **Given**:/**When**:/**Then**: lines
            { grep -E "^\*\*(Given|When|Then)\*\*:" "$input_path" 2>/dev/null || true; } \
                | sed 's/[[:space:]]*$//' \
                | LC_ALL=C sort
        fi
    else
        echo ""
        return 0
    fi
}

# Compute SHA256 hash of assertion content
# Accepts: directory path (tests/features/), single .feature file, or legacy test-specs.md
# Returns just the hash string (no filename), or NO_ASSERTIONS if no step lines found
compute_assertion_hash() {
    local input_path="$1"
    local assertions

    assertions=$(extract_assertions "$input_path")

    if [[ -z "$assertions" ]]; then
        echo "NO_ASSERTIONS"
        return
    fi

    # Use printf to avoid trailing newline issues, pipe to sha256sum
    printf '%s' "$assertions" | shasum -a 256 | cut -d' ' -f1
}

# Derive context.json path from input path
# Supports:
#   Directory: tests/features/ → tests/ → feature_dir/ → context.json (2 levels up)
#   .feature file: tests/features/x.feature → tests/features/ → tests/ → feature_dir/ (3 levels up)
#   Legacy .md: tests/test-specs.md → tests/ → feature_dir/ → context.json (2 levels up)
derive_context_path() {
    local input_path="$1"

    if [[ -d "$input_path" ]]; then
        # Directory input: tests/features/ → go up 2 levels
        local parent_dir
        parent_dir=$(dirname "$input_path")          # tests/
        local feature_dir
        feature_dir=$(dirname "$parent_dir")          # specs/NNN-feature/
        echo "$feature_dir/context.json"
    elif [[ "$input_path" == *.feature ]]; then
        # Single .feature file: tests/features/x.feature → go up 3 levels
        local features_dir
        features_dir=$(dirname "$input_path")         # tests/features/
        local tests_dir
        tests_dir=$(dirname "$features_dir")          # tests/
        local feature_dir
        feature_dir=$(dirname "$tests_dir")           # specs/NNN-feature/
        echo "$feature_dir/context.json"
    else
        # Legacy: tests/test-specs.md → go up 2 levels
        local tests_dir
        tests_dir=$(dirname "$input_path")            # tests/
        local feature_dir
        feature_dir=$(dirname "$tests_dir")           # specs/NNN-feature/
        echo "$feature_dir/context.json"
    fi
}

# Store assertion hash in context.json
# Creates or updates the testify section
# context.json path is derived from input location (not caller-specified)
# For directory input: stores features_dir and file_count
# For legacy file input: stores test_specs_file (backward compat)
store_assertion_hash() {
    local input_path="$1"
    # Accept legacy second arg for backwards compat, but always derive the correct path
    local context_file
    context_file=$(derive_context_path "$input_path")
    local hash
    local timestamp

    hash=$(compute_assertion_hash "$input_path")
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Create context file if it doesn't exist or is empty/invalid
    if [[ ! -f "$context_file" ]] || [[ ! -s "$context_file" ]] || ! jq empty "$context_file" 2>/dev/null; then
        echo '{}' > "$context_file"
    fi

    # Update with jq (create testify section if needed)
    local tmp_file
    tmp_file=$(mktemp)

    if [[ -d "$input_path" ]]; then
        # Directory input: store features_dir and file_count
        # shellcheck disable=SC2012
        local file_count
        file_count=$(ls -1 "$input_path"/*.feature 2>/dev/null | wc -l | tr -d ' ')

        jq --arg hash "$hash" \
           --arg ts "$timestamp" \
           --arg dir "$input_path" \
           --argjson count "$file_count" \
           '.testify = {
               "assertion_hash": $hash,
               "generated_at": $ts,
               "features_dir": $dir,
               "file_count": $count
           }' "$context_file" > "$tmp_file"
    else
        # Legacy file input: store test_specs_file
        jq --arg hash "$hash" \
           --arg ts "$timestamp" \
           --arg file "$input_path" \
           '.testify = {
               "assertion_hash": $hash,
               "generated_at": $ts,
               "test_specs_file": $file
           }' "$context_file" > "$tmp_file"
    fi

    mv "$tmp_file" "$context_file"

    echo "$hash"
}

# Verify assertion hash matches stored value
# Returns: "valid", "invalid", or "missing"
# context.json path is derived from input location
# When a single .feature file is passed but hash was stored from a directory,
# automatically resolves to the parent directory for correct hash comparison
verify_assertion_hash() {
    local input_path="$1"
    # Accept legacy second arg for backwards compat, but always derive the correct path
    local context_file
    context_file=$(derive_context_path "$input_path")

    # Check if context file exists
    if [[ ! -f "$context_file" ]]; then
        echo "missing"
        return
    fi

    # Check if testify section exists
    local stored_hash
    stored_hash=$(jq -r '.testify.assertion_hash // "NONE"' "$context_file" 2>/dev/null)

    if [[ "$stored_hash" == "NONE" ]] || [[ -z "$stored_hash" ]]; then
        echo "missing"
        return
    fi

    # If input is a single .feature file but hash was stored from a directory,
    # resolve to the parent directory for correct comparison
    local hash_input="$input_path"
    if [[ -f "$input_path" ]] && [[ "$input_path" == *.feature ]]; then
        local stored_dir
        stored_dir=$(jq -r '.testify.features_dir // ""' "$context_file" 2>/dev/null)
        if [[ -n "$stored_dir" ]]; then
            # Hash was stored from a directory — use the parent dir of this .feature file
            hash_input=$(dirname "$input_path")
        fi
    fi

    # Compute current hash
    local current_hash
    current_hash=$(compute_assertion_hash "$hash_input")

    if [[ "$stored_hash" == "$current_hash" ]]; then
        echo "valid"
    else
        echo "invalid"
    fi
}

# =============================================================================
# GIT-BASED INTEGRITY FUNCTIONS (Tamper-Resistant)
# =============================================================================

# Git notes namespace for testify hashes
GIT_NOTES_REF="refs/notes/testify"

# Store assertion hash as a git note on the current HEAD
# This is tamper-resistant: modifying requires git history rewrite
store_git_note() {
    local test_specs_file="$1"
    local hash
    local timestamp

    # Check if we're in a git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "ERROR:NOT_GIT_REPO"
        return 1
    fi

    hash=$(compute_assertion_hash "$test_specs_file")
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Create note content with metadata
    local note_content
    note_content=$(cat <<EOF
testify-hash: $hash
generated-at: $timestamp
test-specs-file: $test_specs_file
EOF
)

    # Store as git note on HEAD
    # Use --force to overwrite if note already exists
    if echo "$note_content" | git notes --ref="$GIT_NOTES_REF" add -f -F - HEAD 2>/dev/null; then
        echo "$hash"
    else
        echo "ERROR:GIT_NOTE_FAILED"
        return 1
    fi
}

# Verify assertion hash against git note
# Returns: "valid", "invalid", "missing", or "error:*"
verify_git_note() {
    local test_specs_file="$1"

    # Check if we're in a git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "ERROR:NOT_GIT_REPO"
        return
    fi

    # Get the git note for HEAD
    local note_content
    note_content=$(git notes --ref="$GIT_NOTES_REF" show HEAD 2>/dev/null) || {
        echo "missing"
        return
    }

    # Extract hash from note
    local stored_hash
    stored_hash=$(echo "$note_content" | grep "^testify-hash:" | cut -d' ' -f2)

    if [[ -z "$stored_hash" ]]; then
        echo "missing"
        return
    fi

    # Compute current hash
    local current_hash
    current_hash=$(compute_assertion_hash "$test_specs_file")

    if [[ "$stored_hash" == "$current_hash" ]]; then
        echo "valid"
    else
        echo "invalid"
    fi
}

# =============================================================================
# GIT DIFF INTEGRITY CHECK
# =============================================================================

# Check if assertion files have uncommitted assertion changes
# Returns: "clean", "modified", "untracked", or "error:*"
check_git_diff() {
    local input_path="$1"

    # Check if we're in a git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "ERROR:NOT_GIT_REPO"
        return
    fi

    # Check if file exists
    if [[ ! -f "$input_path" ]]; then
        echo "ERROR:FILE_NOT_FOUND"
        return
    fi

    # Check if file is tracked by git
    if ! git ls-files --error-unmatch "$input_path" >/dev/null 2>&1; then
        echo "untracked"
        return
    fi

    # Check for uncommitted changes to assertion lines specifically
    # Get diff of the file against HEAD
    local diff_output
    diff_output=$(git diff HEAD -- "$input_path" 2>/dev/null) || {
        echo "ERROR:GIT_DIFF_FAILED"
        return
    }

    # If no diff at all, file is clean
    if [[ -z "$diff_output" ]]; then
        echo "clean"
        return
    fi

    # Check if any assertion lines were modified
    # Look for added (+) or removed (-) assertion lines in either format:
    # Legacy test-specs.md: **Given**:, **When**:, **Then**:
    # Gherkin .feature: Given ..., When ..., Then ..., And ..., But ...
    if echo "$diff_output" | grep -qE '^[+-]\*\*(Given|When|Then)\*\*:'; then
        echo "modified"
    elif echo "$diff_output" | grep -qE '^[+-][[:space:]]*(Given|When|Then|And|But) '; then
        echo "modified"
    else
        # Changes exist but not to assertions (e.g., formatting, comments)
        echo "clean"
    fi
}

# Comprehensive integrity check combining all methods
# Accepts: features directory, single .feature file, or legacy test-specs.md
# Returns JSON with status from each check method
# tdd_determination: "mandatory", "optional", or "forbidden"
comprehensive_integrity_check() {
    local input_path="$1"
    # Second arg is now ignored — context path derived from input location
    local constitution_file="${3:-$2}"  # Support both old 3-arg and new 2-arg calling
    local context_file
    context_file=$(derive_context_path "$input_path")

    local hash_result="skipped"
    local git_note_result="skipped"
    local git_diff_result="skipped"
    local tdd_determination="unknown"
    local overall_status="unknown"
    local block_reason=""

    # Get TDD determination from constitution
    if [[ -f "$constitution_file" ]]; then
        local tdd_json
        tdd_json=$(assess_tdd_requirements "$constitution_file")
        tdd_determination=$(echo "$tdd_json" | jq -r '.determination // "unknown"')
    fi

    # Check context.json hash
    if [[ -f "$context_file" ]]; then
        hash_result=$(verify_assertion_hash "$input_path")
    else
        hash_result="missing"
    fi

    # Check git-based integrity (if in git repo and input is a file)
    # Git note/diff checks only apply to individual files, not directories
    if git rev-parse --git-dir >/dev/null 2>&1; then
        if [[ -f "$input_path" ]]; then
            git_note_result=$(verify_git_note "$input_path")
            git_diff_result=$(check_git_diff "$input_path")
        else
            # For directory input, git note/diff not applicable (multiple files)
            git_note_result="skipped"
            git_diff_result="skipped"
        fi
    fi

    # Determine overall status and blocking conditions
    # Priority: invalid > modified > missing (when TDD mandatory) > valid/clean

    if [[ "$hash_result" == "invalid" ]] || [[ "$git_note_result" == "invalid" ]]; then
        overall_status="BLOCKED"
        block_reason="Assertions were modified since testify ran"
    elif [[ "$git_diff_result" == "modified" ]]; then
        overall_status="BLOCKED"
        block_reason="Uncommitted changes to assertions detected"
    elif [[ "$tdd_determination" == "mandatory" ]]; then
        # For mandatory TDD, missing hash is also a blocker
        if [[ "$hash_result" == "missing" ]] && [[ "$git_note_result" != "valid" ]]; then
            overall_status="BLOCKED"
            block_reason="TDD is mandatory but no integrity hash found"
        else
            overall_status="PASS"
        fi
    else
        # For optional TDD, missing is just a warning
        if [[ "$hash_result" == "valid" ]] || [[ "$git_note_result" == "valid" ]]; then
            overall_status="PASS"
        elif [[ "$hash_result" == "missing" ]] && [[ "$git_note_result" != "valid" ]]; then
            overall_status="WARN"
            block_reason="No integrity hash found (TDD is optional)"
        else
            overall_status="PASS"
        fi
    fi

    # Output JSON result
    cat <<EOF
{
    "overall_status": "$overall_status",
    "block_reason": "$block_reason",
    "tdd_determination": "$tdd_determination",
    "checks": {
        "context_hash": "$hash_result",
        "git_note": "$git_note_result",
        "git_diff": "$git_diff_result"
    }
}
EOF
}

# Get TDD determination only (for quick checks)
# Returns: "mandatory", "optional", "forbidden", or "unknown"
get_tdd_determination() {
    local constitution_file="$1"

    if [[ ! -f "$constitution_file" ]]; then
        echo "unknown"
        return
    fi

    local tdd_json
    tdd_json=$(assess_tdd_requirements "$constitution_file")
    echo "$tdd_json" | jq -r '.determination // "unknown"'
}

# =============================================================================
# TEST SPEC GENERATION FUNCTIONS
# =============================================================================

# Count acceptance scenarios in spec file
count_acceptance_scenarios() {
    local spec_file="$1"

    if [[ ! -f "$spec_file" ]]; then
        echo "0"
        return
    fi

    # Count Given/When/Then patterns, excluding HTML comments
    # First remove HTML comments, then count patterns
    local count
    count=$(sed 's/<!--.*-->//g' "$spec_file" | grep -ci "\*\*Given\*\*\|\*\*When\*\*" 2>/dev/null) || count=0
    echo "$count"
}

# Check if spec has acceptance scenarios
has_acceptance_scenarios() {
    local spec_file="$1"
    local count
    count=$(count_acceptance_scenarios "$spec_file")

    if [[ "$count" -gt 0 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

# If run directly with arguments
if [[ $# -gt 0 ]]; then
    case "$1" in
        assess-tdd)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 assess-tdd <constitution-file>"
                exit 1
            fi
            assess_tdd_requirements "$2"
            ;;
        get-tdd-determination)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 get-tdd-determination <constitution-file>"
                exit 1
            fi
            get_tdd_determination "$2"
            ;;
        count-scenarios)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 count-scenarios <spec-file>"
                exit 1
            fi
            count_acceptance_scenarios "$2"
            ;;
        has-scenarios)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 has-scenarios <spec-file>"
                exit 1
            fi
            has_acceptance_scenarios "$2"
            ;;
        extract-assertions)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 extract-assertions <features-dir-or-file>"
                exit 1
            fi
            extract_assertions "$2"
            ;;
        compute-hash)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 compute-hash <features-dir-or-file>"
                exit 1
            fi
            compute_assertion_hash "$2"
            ;;
        store-hash|rehash)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 store-hash <features-dir-or-file>"
                exit 1
            fi
            store_assertion_hash "$2"
            ;;
        verify-hash)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 verify-hash <features-dir-or-file>"
                exit 1
            fi
            verify_assertion_hash "$2"
            ;;
        store-git-note)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 store-git-note <test-specs-file>"
                exit 1
            fi
            store_git_note "$2"
            ;;
        verify-git-note)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 verify-git-note <test-specs-file>"
                exit 1
            fi
            verify_git_note "$2"
            ;;
        check-git-diff)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 check-git-diff <test-specs-file>"
                exit 1
            fi
            check_git_diff "$2"
            ;;
        comprehensive-check)
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 comprehensive-check <test-specs-file> <constitution-file>"
                exit 1
            fi
            comprehensive_integrity_check "$2" "$3"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Available commands:"
            echo "  TDD Assessment:"
            echo "    assess-tdd <constitution-file>        - Full TDD assessment (JSON)"
            echo "    get-tdd-determination <constitution>  - Just the determination"
            echo "  Scenario Counting:"
            echo "    count-scenarios <spec-file>           - Count acceptance scenarios"
            echo "    has-scenarios <spec-file>             - Check if scenarios exist"
            echo "  Hash-based Integrity (context.json auto-derived from input path):"
            echo "    extract-assertions <dir-or-file>      - Extract step lines (.feature dir/file or legacy .md)"
            echo "    compute-hash <dir-or-file>            - Compute SHA256 hash"
            echo "    store-hash|rehash <dir-or-file>       - Atomic compute + store hash in feature's context.json"
            echo "    verify-hash <dir-or-file>             - Verify against feature's context.json"
            echo "  Git-based Integrity (tamper-resistant):"
            echo "    store-git-note <test-specs-file>      - Store hash as git note"
            echo "    verify-git-note <test-specs-file>     - Verify against git note"
            echo "    check-git-diff <test-specs-file>      - Check uncommitted changes"
            echo "  Comprehensive:"
            echo "    comprehensive-check <dir-or-file> <constitution-file>"
            exit 1
            ;;
    esac
fi
