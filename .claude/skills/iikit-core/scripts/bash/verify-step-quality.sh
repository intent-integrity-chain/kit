#!/usr/bin/env bash
# Verify step definition quality using AST parsing and regex analysis
# Detects empty bodies, tautological assertions, and missing assertions
# Usage: verify-step-quality.sh [--json] <step-definitions-dir> <language>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# PYTHON AST ANALYSIS
# =============================================================================

analyze_python() {
    local step_defs_dir="$1"
    local parser="ast"

    # Check if python3 with ast module is available
    if ! python3 -c "import ast" 2>/dev/null; then
        analyze_regex_fallback "$step_defs_dir" "python"
        return
    fi

    # Inline Python script for AST analysis
    local python_script
    python_script=$(cat <<'PYEOF'
import ast
import sys
import os
import json

TAUTOLOGY_PATTERNS = {
    "assert True",
    "assert 1",
    "assert not False",
    "assert not 0",
}

ASSERTION_KEYWORDS = {"assert", "assertEqual", "assertIn", "assertTrue",
    "assertFalse", "assertRaises", "assertIsNone", "assertIsNotNone",
    "assert_that", "should", "expect", "verify"}

# BDD decorator names
BDD_DECORATORS_PYTEST = {"given", "when", "then"}
BDD_DECORATORS_BEHAVE = {"step", "given", "when", "then"}

def get_step_type(decorator_name):
    """Classify a decorator as given/when/then."""
    name_lower = decorator_name.lower()
    if name_lower in ("given",):
        return "given"
    elif name_lower in ("when",):
        return "when"
    elif name_lower in ("then",):
        return "then"
    return "step"

def is_empty_body(func_node):
    """Check if function body is just pass, ellipsis, or docstring only."""
    body = func_node.body
    real_stmts = []
    for stmt in body:
        # Skip docstrings (ast.Constant with str value)
        if isinstance(stmt, ast.Expr) and isinstance(stmt.value, ast.Constant):
            if isinstance(stmt.value.value, str):
                continue
        real_stmts.append(stmt)

    if len(real_stmts) == 0:
        return True
    if len(real_stmts) == 1:
        stmt = real_stmts[0]
        if isinstance(stmt, ast.Pass):
            return True
        if isinstance(stmt, ast.Expr) and isinstance(stmt.value, ast.Constant):
            return True
    return False

def is_tautology(func_node):
    """Check if function body contains only tautological assertions."""
    for node in ast.walk(func_node):
        if isinstance(node, ast.Assert):
            # Check for assert True, assert 1
            test = node.test
            if isinstance(test, ast.Constant):
                if test.value in (True, 1):
                    return True
            # Check for assert not False, assert not 0
            if isinstance(test, ast.UnaryOp) and isinstance(test.op, ast.Not):
                operand = test.operand
                if isinstance(operand, ast.Constant) and operand.value in (False, 0):
                    return True
    return False

def has_assertion(func_node):
    """Check if function body contains any assertion keyword."""
    source_lines = []
    for node in ast.walk(func_node):
        # Check assert statements
        if isinstance(node, ast.Assert):
            return True
        # Check function calls that look like assertions
        if isinstance(node, ast.Call):
            func = node.func
            name = ""
            if isinstance(func, ast.Name):
                name = func.id
            elif isinstance(func, ast.Attribute):
                name = func.attr
            if any(kw in name.lower() for kw in ASSERTION_KEYWORDS):
                return True
        # Check for raise statements (custom assertion patterns)
        if isinstance(node, ast.Raise):
            return True
    return False

def get_bdd_decorator_info(func_node):
    """Extract BDD step decorator info. Returns (step_type, step_text) or None."""
    for decorator in func_node.decorator_list:
        name = ""
        args = []
        if isinstance(decorator, ast.Call):
            func = decorator.func
            if isinstance(func, ast.Name):
                name = func.id.lower()
            elif isinstance(func, ast.Attribute):
                name = func.attr.lower()
            args = decorator.args
        elif isinstance(decorator, ast.Name):
            name = decorator.id.lower()
        elif isinstance(decorator, ast.Attribute):
            name = decorator.attr.lower()

        if name in BDD_DECORATORS_PYTEST or name in BDD_DECORATORS_BEHAVE:
            step_text = ""
            if args and isinstance(args[0], ast.Constant):
                step_text = str(args[0].value)
            step_type = get_step_type(name)
            return step_type, step_text

    return None

def analyze_file(filepath):
    """Analyze a single Python step definition file."""
    issues = []
    step_count = 0

    try:
        with open(filepath, "r") as f:
            source = f.read()
        tree = ast.parse(source, filename=filepath)
    except (SyntaxError, UnicodeDecodeError) as e:
        return 0, [{"step": "(parse error)", "file": filepath, "line": 0,
                     "issue": "PARSE_ERROR", "severity": "WARN",
                     "message": str(e)}]

    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue

        info = get_bdd_decorator_info(node)
        if info is None:
            continue

        step_type, step_text = info
        step_count += 1
        step_label = step_text if step_text else node.name

        # Check for empty body
        if is_empty_body(node):
            issues.append({
                "step": step_label,
                "file": filepath,
                "line": node.lineno,
                "issue": "EMPTY_BODY",
                "severity": "FAIL"
            })
            continue

        # Check for tautology (primarily in Then steps, but flag in any)
        if is_tautology(node):
            issues.append({
                "step": step_label,
                "file": filepath,
                "line": node.lineno,
                "issue": "TAUTOLOGY",
                "severity": "FAIL"
            })
            continue

        # Check for missing assertions in Then steps
        if step_type == "then" and not has_assertion(node):
            issues.append({
                "step": step_label,
                "file": filepath,
                "line": node.lineno,
                "issue": "NO_ASSERTION",
                "severity": "FAIL"
            })

    return step_count, issues

def main():
    step_defs_dir = sys.argv[1]
    all_issues = []
    total_steps = 0

    for root, dirs, files in os.walk(step_defs_dir):
        for fname in files:
            if not fname.endswith(".py"):
                continue
            filepath = os.path.join(root, fname)
            count, issues = analyze_file(filepath)
            total_steps += count
            all_issues.extend(issues)

    fail_count = sum(1 for i in all_issues if i["severity"] == "FAIL")
    pass_count = total_steps - fail_count

    status = "BLOCKED" if fail_count > 0 else "PASS"

    result = {
        "status": status,
        "language": "python",
        "parser": "ast",
        "total_steps": total_steps,
        "quality_pass": pass_count,
        "quality_fail": fail_count,
        "details": all_issues
    }
    print(json.dumps(result))

if __name__ == "__main__":
    main()
PYEOF
    )

    python3 -c "$python_script" "$step_defs_dir"
}

# =============================================================================
# JAVASCRIPT / TYPESCRIPT ANALYSIS
# =============================================================================

analyze_javascript() {
    local step_defs_dir="$1"
    local lang="${2:-javascript}"
    local parser="node"

    # Check if node is available
    if ! node -e "process.exit(0)" 2>/dev/null; then
        analyze_regex_fallback "$step_defs_dir" "$lang"
        return
    fi

    # For TypeScript, check if ts-node or tsc is available (informational)
    local ts_note=""
    if [[ "$lang" == "typescript" ]]; then
        if ! command -v ts-node >/dev/null 2>&1 && ! command -v tsc >/dev/null 2>&1; then
            ts_note="Note: ts-node/tsc not found; analyzing .ts files as text via Node regex."
        fi
    fi

    # Inline Node.js script for analysis
    local node_script
    node_script=$(cat <<'JSEOF'
const fs = require('fs');
const path = require('path');

const TAUTOLOGY_PATTERNS = [
    /expect\s*\(\s*true\s*\)\s*\.\s*toBe\s*\(\s*true\s*\)/,
    /expect\s*\(\s*1\s*\)\s*\.\s*toBe\s*\(\s*1\s*\)/,
    /expect\s*\(\s*true\s*\)\s*\.\s*toBeTruthy\s*\(\s*\)/,
    /assert\s*\.\s*ok\s*\(\s*true\s*\)/,
    /assert\s*\(\s*true\s*\)/,
    /assert\.strictEqual\s*\(\s*true\s*,\s*true\s*\)/,
];

const ASSERTION_PATTERNS = [
    /\bexpect\s*\(/,
    /\bassert\b/,
    /\bshould\b/,
    /\.to\.\w+/,
    /\.toEqual\b/,
    /\.toBe\b/,
    /\.toHaveBeenCalled/,
    /\.toThrow/,
    /\.rejects/,
    /\.resolves/,
];

const STEP_PATTERN = /\b(Given|When|Then)\s*\(\s*(['"`\/])([\s\S]*?)\2\s*,\s*((?:async\s+)?(?:function\s*\([^)]*\)|(?:\([^)]*\)|\w+)\s*=>))\s*\{/g;

function findStepBlocks(content) {
    const steps = [];
    const lines = content.split('\n');

    // Reset regex
    STEP_PATTERN.lastIndex = 0;
    let match;
    while ((match = STEP_PATTERN.exec(content)) !== null) {
        const stepType = match[1].toLowerCase();
        const stepText = match[3];
        const matchStart = match.index;

        // Find line number
        let lineNo = 1;
        for (let i = 0; i < matchStart && i < content.length; i++) {
            if (content[i] === '\n') lineNo++;
        }

        // Extract body by counting braces
        let braceDepth = 0;
        let bodyStart = content.indexOf('{', match.index + match[0].length - 1);
        let bodyEnd = bodyStart;
        let foundFirst = false;
        for (let i = bodyStart; i < content.length; i++) {
            if (content[i] === '{') {
                braceDepth++;
                foundFirst = true;
            }
            if (content[i] === '}') {
                braceDepth--;
            }
            if (foundFirst && braceDepth === 0) {
                bodyEnd = i;
                break;
            }
        }

        const body = content.substring(bodyStart + 1, bodyEnd).trim();
        steps.push({ stepType, stepText, body, line: lineNo });
    }
    return steps;
}

function analyzeFile(filepath) {
    const content = fs.readFileSync(filepath, 'utf-8');
    const steps = findStepBlocks(content);
    const issues = [];

    for (const step of steps) {
        const { stepType, stepText, body, line } = step;
        const label = stepText || `(${stepType} step)`;

        // Check empty body
        if (body === '' || body === '// TODO' || body === '/* TODO */') {
            issues.push({ step: label, file: filepath, line, issue: 'EMPTY_BODY', severity: 'FAIL' });
            continue;
        }

        // Check tautology
        const isTautology = TAUTOLOGY_PATTERNS.some(p => p.test(body));
        if (isTautology) {
            issues.push({ step: label, file: filepath, line, issue: 'TAUTOLOGY', severity: 'FAIL' });
            continue;
        }

        // Check for missing assertions in Then steps
        if (stepType === 'then') {
            const hasAssertion = ASSERTION_PATTERNS.some(p => p.test(body));
            if (!hasAssertion) {
                issues.push({ step: label, file: filepath, line, issue: 'NO_ASSERTION', severity: 'FAIL' });
            }
        }
    }

    return { count: steps.length, issues };
}

function walkDir(dir, extensions) {
    let files = [];
    try {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            if (entry.isDirectory()) {
                files = files.concat(walkDir(fullPath, extensions));
            } else if (extensions.some(ext => entry.name.endsWith(ext))) {
                files.push(fullPath);
            }
        }
    } catch (e) {
        // Directory not readable
    }
    return files;
}

const stepDefsDir = process.argv[2];
const lang = process.argv[3] || 'javascript';
const extensions = lang === 'typescript' ? ['.ts', '.tsx'] : ['.js', '.jsx', '.mjs'];

const files = walkDir(stepDefsDir, extensions);
let totalSteps = 0;
let allIssues = [];

for (const f of files) {
    const { count, issues } = analyzeFile(f);
    totalSteps += count;
    allIssues = allIssues.concat(issues);
}

const failCount = allIssues.filter(i => i.severity === 'FAIL').length;
const passCount = totalSteps - failCount;
const status = failCount > 0 ? 'BLOCKED' : 'PASS';

const result = {
    status,
    language: lang,
    parser: 'node',
    total_steps: totalSteps,
    quality_pass: passCount,
    quality_fail: failCount,
    details: allIssues
};

console.log(JSON.stringify(result));
JSEOF
    )

    local tmpjs
    tmpjs=$(mktemp /tmp/verify-step-quality-XXXXXX.cjs)
    echo "$node_script" > "$tmpjs"
    node "$tmpjs" "$step_defs_dir" "$lang"
    rm -f "$tmpjs"
}

# =============================================================================
# GO ANALYSIS
# =============================================================================

analyze_go() {
    local step_defs_dir="$1"

    # Check if go binary is available
    if ! command -v go >/dev/null 2>&1; then
        analyze_regex_fallback "$step_defs_dir" "go"
        return
    fi

    # Use regex-based analysis for Go (avoids need for compilable Go module)
    # Go BDD frameworks (godog) use s.Step() or s.Given()/s.When()/s.Then()
    local total_steps=0
    local details="[]"
    local all_issues=""

    while IFS= read -r -d '' gofile; do
        # Find step definitions: patterns like func(ctx, ...) { or Step("...", func...
        # godog pattern: s.Step(`regex`, handlerFunc)
        # Also look for standalone handler functions

        local file_content
        file_content=$(<"$gofile")

        # Count step registrations
        local step_count
        step_count=$(echo "$file_content" | grep -cE '^\s*s\.(Step|Given|When|Then)\(' 2>/dev/null) || step_count=0

        # Find handler function bodies for emptiness
        # Look for func declarations that follow step patterns
        while IFS= read -r line_info; do
            local lineno="${line_info%%:*}"
            local line_content="${line_info#*:}"
            total_steps=$((total_steps + 1))

            # Extract the step text if available
            local step_text
            step_text=$(echo "$line_content" | grep -oE '["`]([^"`]+)["`]' | head -1 | tr -d '"`') || step_text="(go step)"

            # Check for empty handler: func(...) { }  or func(...) { return nil }
            # Look ahead from this line for the function body
            local after_line
            after_line=$(tail -n +"$lineno" "$gofile" 2>/dev/null | head -20)

            # Check if body is essentially empty (only contains return nil or nothing)
            local body_lines
            body_lines=$(echo "$after_line" | sed -n '/^[[:space:]]*func\|{/,/^[[:space:]]*}/p' | grep -v '^[[:space:]]*$' | grep -v '{' | grep -v '}' | grep -v 'return nil' | grep -v '//')
            if [[ -z "$body_lines" ]]; then
                all_issues="${all_issues}{\"step\":\"${step_text}\",\"file\":\"${gofile}\",\"line\":${lineno},\"issue\":\"EMPTY_BODY\",\"severity\":\"FAIL\"},"
            fi
        done < <(grep -nE '^\s*s\.(Step|Given|When|Then)\(' "$gofile" 2>/dev/null || true)

    done < <(find "$step_defs_dir" -name "*.go" -print0 2>/dev/null)

    # Remove trailing comma and build array
    all_issues="${all_issues%,}"
    if [[ -n "$all_issues" ]]; then
        details="[${all_issues}]"
    fi

    local fail_count
    fail_count=$(echo "$details" | grep -o '"severity":"FAIL"' | wc -l | tr -d ' ')
    local pass_count=$((total_steps - fail_count))
    local status="PASS"
    [[ "$fail_count" -gt 0 ]] && status="BLOCKED"

    cat <<EOF
{"status":"${status}","language":"go","parser":"regex","total_steps":${total_steps},"quality_pass":${pass_count},"quality_fail":${fail_count},"details":${details}}
EOF
}

# =============================================================================
# REGEX FALLBACK (Java, Rust, C#, and unsupported languages)
# =============================================================================

analyze_regex_fallback() {
    local step_defs_dir="$1"
    local language="$2"

    local extensions=""
    local annotation_pattern=""

    case "$language" in
        java)
            extensions="*.java"
            annotation_pattern='@(Given|When|Then)\s*\('
            ;;
        rust)
            extensions="*.rs"
            annotation_pattern='#\[(given|when|then)\('
            ;;
        csharp|c#)
            extensions="*.cs"
            annotation_pattern='\[(Given|When|Then)\s*\('
            ;;
        python)
            extensions="*.py"
            annotation_pattern='@(given|when|then)\s*\('
            ;;
        go)
            extensions="*.go"
            annotation_pattern='s\.(Step|Given|When|Then)\s*\('
            ;;
        javascript|js)
            extensions="*.js"
            annotation_pattern='\b(Given|When|Then)\s*\('
            ;;
        typescript|ts)
            extensions="*.ts"
            annotation_pattern='\b(Given|When|Then)\s*\('
            ;;
        *)
            extensions="*.*"
            annotation_pattern='(Given|When|Then)\s*\('
            ;;
    esac

    local total_steps=0
    local all_issues=""
    local parser_note="DEGRADED_ANALYSIS: No AST parser available for ${language}. Using regex heuristics."

    # Find step definition files
    while IFS= read -r -d '' filepath; do
        # Count step annotations/decorators
        local step_lines
        step_lines=$(grep -nE "$annotation_pattern" "$filepath" 2>/dev/null || true)

        while IFS= read -r match_line; do
            [[ -z "$match_line" ]] && continue
            total_steps=$((total_steps + 1))

            local lineno="${match_line%%:*}"
            local line_content="${match_line#*:}"

            # Extract step text
            local step_text
            step_text=$(echo "$line_content" | grep -oE '"([^"]+)"' | head -1 | tr -d '"') || true
            [[ -z "$step_text" ]] && step_text=$(echo "$line_content" | grep -oE "'([^']+)'" | head -1 | tr -d "'") || true
            [[ -z "$step_text" ]] && step_text="(${language} step at line ${lineno})"

            # Look ahead for body content (next 20 lines after the step definition)
            local body_region
            body_region=$(tail -n +"$lineno" "$filepath" 2>/dev/null | head -30)

            # Check for empty body patterns
            local is_empty=false
            case "$language" in
                java)
                    # Empty method: just { } or { // TODO }
                    if echo "$body_region" | grep -qE '^\s*\{[[:space:]]*\}' 2>/dev/null; then
                        is_empty=true
                    fi
                    ;;
                python)
                    # pass only
                    if echo "$body_region" | grep -qE '^\s+pass\s*$' 2>/dev/null; then
                        is_empty=true
                    fi
                    ;;
                *)
                    # Generic: look for { } or { return; }
                    if echo "$body_region" | grep -qE '^\s*\{[[:space:]]*\}' 2>/dev/null; then
                        is_empty=true
                    fi
                    ;;
            esac

            if $is_empty; then
                all_issues="${all_issues}{\"step\":$(printf '%s' "$step_text" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "\"${step_text}\""),\"file\":\"${filepath}\",\"line\":${lineno},\"issue\":\"EMPTY_BODY\",\"severity\":\"FAIL\"},"
            fi

        done <<< "$step_lines"
    done < <(find "$step_defs_dir" -name "$extensions" -print0 2>/dev/null)

    # Remove trailing comma and build array
    all_issues="${all_issues%,}"
    local details="[]"
    if [[ -n "$all_issues" ]]; then
        details="[${all_issues}]"
    fi

    local fail_count
    fail_count=$(echo "$details" | grep -o '"severity":"FAIL"' | wc -l | tr -d ' ')
    local pass_count=$((total_steps - fail_count))
    local status="PASS"
    [[ "$fail_count" -gt 0 ]] && status="BLOCKED"

    cat <<EOF
{"status":"${status}","language":"${language}","parser":"regex","parser_note":"${parser_note}","total_steps":${total_steps},"quality_pass":${pass_count},"quality_fail":${fail_count},"details":${details}}
EOF
}

# =============================================================================
# MAIN
# =============================================================================

JSON_MODE=false
[[ "${1:-}" == "--json" ]] && { JSON_MODE=true; shift; }

STEP_DEFS_DIR="${1:?Usage: verify-step-quality.sh [--json] <step-definitions-dir> <language>}"
LANGUAGE="${2:?Usage: verify-step-quality.sh [--json] <step-definitions-dir> <language>}"

# Validate directory exists
if [[ ! -d "$STEP_DEFS_DIR" ]]; then
    if $JSON_MODE; then
        echo '{"status":"ERROR","language":"'"$LANGUAGE"'","parser":"none","error":"Step definitions directory not found: '"$STEP_DEFS_DIR"'","total_steps":0,"quality_pass":0,"quality_fail":0,"details":[]}'
    else
        echo "ERROR: Step definitions directory not found: $STEP_DEFS_DIR" >&2
    fi
    exit 1
fi

# Normalize language
LANGUAGE=$(echo "$LANGUAGE" | tr '[:upper:]' '[:lower:]')

# Route to appropriate analyzer
result=""
case "$LANGUAGE" in
    python|py)
        result=$(analyze_python "$STEP_DEFS_DIR")
        ;;
    javascript|js)
        result=$(analyze_javascript "$STEP_DEFS_DIR" "javascript")
        ;;
    typescript|ts)
        result=$(analyze_javascript "$STEP_DEFS_DIR" "typescript")
        ;;
    go|golang)
        result=$(analyze_go "$STEP_DEFS_DIR")
        ;;
    java|rust|csharp|c#)
        result=$(analyze_regex_fallback "$STEP_DEFS_DIR" "$LANGUAGE")
        ;;
    *)
        result=$(analyze_regex_fallback "$STEP_DEFS_DIR" "$LANGUAGE")
        ;;
esac

# Helper to extract JSON field value (handles both compact and pretty JSON)
extract_json_string() {
    local json="$1"
    local field="$2"
    local matched
    matched=$(echo "$json" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" 2>/dev/null | head -1) || true
    if [[ -n "$matched" ]]; then
        echo "$matched" | sed 's/.*:[[:space:]]*"//;s/"$//'
    fi
}

extract_json_number() {
    local json="$1"
    local field="$2"
    local matched
    matched=$(echo "$json" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*[0-9]*" 2>/dev/null | head -1) || true
    if [[ -n "$matched" ]]; then
        echo "$matched" | sed 's/.*:[[:space:]]*//'
    else
        echo "0"
    fi
}

# Output result
if $JSON_MODE; then
    echo "$result"
else
    # Human-readable output
    local_status=$(extract_json_string "$result" "status")
    local_lang=$(extract_json_string "$result" "language")
    local_parser=$(extract_json_string "$result" "parser")
    local_total=$(extract_json_number "$result" "total_steps")
    local_pass=$(extract_json_number "$result" "quality_pass")
    local_fail=$(extract_json_number "$result" "quality_fail")

    echo "Step Quality Analysis"
    echo "  Language: $local_lang"
    echo "  Parser:   $local_parser"
    echo "  Status:   $local_status"
    echo "  Total:    ${local_total:-0} steps"
    echo "  Pass:     ${local_pass:-0}"
    echo "  Fail:     ${local_fail:-0}"

    # Show parser note if present
    local_note=$(extract_json_string "$result" "parser_note")
    if [[ -n "$local_note" ]]; then
        echo "  Note:     $local_note"
    fi

    # Show details if any
    if [[ "${local_fail:-0}" -gt 0 ]]; then
        echo ""
        echo "  Issues:"
        # Parse details array items
        echo "$result" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
for d in data.get('details', []):
    print(f\"    [{d['severity']}] {d['issue']}: {d['step']} ({d['file']}:{d['line']})\")
" 2>/dev/null || echo "    (install python3 for detailed issue display)"
    fi
fi

# Exit code: 0 for PASS/DEGRADED, non-zero for BLOCKED
local_status=$(extract_json_string "$result" "status")
if [[ "$local_status" == "BLOCKED" ]]; then
    exit 1
fi
exit 0
