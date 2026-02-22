#!/usr/bin/env pwsh
# Verify step definition quality using AST parsing and regex analysis
# Detects empty bodies, tautological assertions, and missing assertions
# Usage: verify-step-quality.ps1 [--json] <step-definitions-dir> <language>

param(
    [switch]$json,

    [Parameter(Position = 0)]
    [string]$Arg1,

    [Parameter(Position = 1)]
    [string]$Arg2,

    [Parameter(Position = 2)]
    [string]$Arg3
)

$ErrorActionPreference = "Stop"

# Parse arguments: handle --json switch or positional --json string
$JsonMode = $false
$StepDefsDir = ""
$Language = ""

if ($json) {
    $JsonMode = $true
    $StepDefsDir = $Arg1
    $Language = $Arg2
} elseif ($Arg1 -eq "--json") {
    $JsonMode = $true
    $StepDefsDir = $Arg2
    $Language = $Arg3
} else {
    $StepDefsDir = $Arg1
    $Language = $Arg2
}

if (-not $StepDefsDir -or -not $Language) {
    Write-Error "Usage: verify-step-quality.ps1 [--json] <step-definitions-dir> <language>"
    exit 1
}

# Validate directory
if (-not (Test-Path $StepDefsDir -PathType Container)) {
    if ($JsonMode) {
        $errorResult = @{
            status = "ERROR"
            language = $Language
            parser = "none"
            error = "Step definitions directory not found: $StepDefsDir"
            total_steps = 0
            quality_pass = 0
            quality_fail = 0
            details = @()
        }
        Write-Output ($errorResult | ConvertTo-Json -Depth 5 -Compress)
    } else {
        Write-Error "ERROR: Step definitions directory not found: $StepDefsDir"
    }
    exit 1
}

# Normalize language
$Language = $Language.ToLower()

# =============================================================================
# PYTHON AST ANALYSIS
# =============================================================================

function Invoke-PythonAnalysis {
    param([string]$StepDefsDir)

    # Check if python3 with ast module is available
    try {
        $null = & python3 -c "import ast" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "no ast" }
    } catch {
        return Invoke-RegexFallback -StepDefsDir $StepDefsDir -Language "python"
    }

    $pythonScript = @'
import ast
import sys
import os
import json

ASSERTION_KEYWORDS = {"assert", "assertEqual", "assertIn", "assertTrue",
    "assertFalse", "assertRaises", "assertIsNone", "assertIsNotNone",
    "assert_that", "should", "expect", "verify"}

BDD_DECORATORS = {"given", "when", "then", "step"}

def get_step_type(name):
    name_lower = name.lower()
    if name_lower == "given": return "given"
    elif name_lower == "when": return "when"
    elif name_lower == "then": return "then"
    return "step"

def is_empty_body(func_node):
    body = func_node.body
    real_stmts = []
    for stmt in body:
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
    for node in ast.walk(func_node):
        if isinstance(node, ast.Assert):
            test = node.test
            if isinstance(test, ast.Constant):
                if test.value in (True, 1):
                    return True
            if isinstance(test, ast.UnaryOp) and isinstance(test.op, ast.Not):
                operand = test.operand
                if isinstance(operand, ast.Constant) and operand.value in (False, 0):
                    return True
    return False

def has_assertion(func_node):
    for node in ast.walk(func_node):
        if isinstance(node, ast.Assert):
            return True
        if isinstance(node, ast.Call):
            func = node.func
            name = ""
            if isinstance(func, ast.Name):
                name = func.id
            elif isinstance(func, ast.Attribute):
                name = func.attr
            if any(kw in name.lower() for kw in ASSERTION_KEYWORDS):
                return True
        if isinstance(node, ast.Raise):
            return True
    return False

def get_bdd_decorator_info(func_node):
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
        if name in BDD_DECORATORS:
            step_text = ""
            if args and isinstance(args[0], ast.Constant):
                step_text = str(args[0].value)
            return get_step_type(name), step_text
    return None

def analyze_file(filepath):
    issues = []
    step_count = 0
    try:
        with open(filepath, "r") as f:
            source = f.read()
        tree = ast.parse(source, filename=filepath)
    except (SyntaxError, UnicodeDecodeError) as e:
        return 0, [{"step": "(parse error)", "file": filepath, "line": 0,
                     "issue": "PARSE_ERROR", "severity": "WARN", "message": str(e)}]
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        info = get_bdd_decorator_info(node)
        if info is None:
            continue
        step_type, step_text = info
        step_count += 1
        step_label = step_text if step_text else node.name
        if is_empty_body(node):
            issues.append({"step": step_label, "file": filepath, "line": node.lineno,
                           "issue": "EMPTY_BODY", "severity": "FAIL"})
            continue
        if is_tautology(node):
            issues.append({"step": step_label, "file": filepath, "line": node.lineno,
                           "issue": "TAUTOLOGY", "severity": "FAIL"})
            continue
        if step_type == "then" and not has_assertion(node):
            issues.append({"step": step_label, "file": filepath, "line": node.lineno,
                           "issue": "NO_ASSERTION", "severity": "FAIL"})
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
    result = {"status": status, "language": "python", "parser": "ast",
              "total_steps": total_steps, "quality_pass": pass_count,
              "quality_fail": fail_count, "details": all_issues}
    print(json.dumps(result))

if __name__ == "__main__":
    main()
'@

    $result = & python3 -c $pythonScript $StepDefsDir 2>&1
    return $result
}

# =============================================================================
# JAVASCRIPT / TYPESCRIPT ANALYSIS
# =============================================================================

function Invoke-JavaScriptAnalysis {
    param(
        [string]$StepDefsDir,
        [string]$Lang = "javascript"
    )

    # Check if node is available
    try {
        & node -e "process.exit(0)" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "no node" }
    } catch {
        return Invoke-RegexFallback -StepDefsDir $StepDefsDir -Language $Lang
    }

    $nodeScript = @'
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
    /\bexpect\s*\(/, /\bassert\b/, /\bshould\b/, /\.to\.\w+/,
    /\.toEqual\b/, /\.toBe\b/, /\.toHaveBeenCalled/, /\.toThrow/,
    /\.rejects/, /\.resolves/,
];

const STEP_PATTERN = /\b(Given|When|Then)\s*\(\s*(['"`\/])([\s\S]*?)\2\s*,\s*((?:async\s+)?(?:function\s*\([^)]*\)|(?:\([^)]*\)|\w+)\s*=>))\s*\{/g;

function findStepBlocks(content) {
    const steps = [];
    STEP_PATTERN.lastIndex = 0;
    let match;
    while ((match = STEP_PATTERN.exec(content)) !== null) {
        const stepType = match[1].toLowerCase();
        const stepText = match[3];
        let lineNo = 1;
        for (let i = 0; i < match.index; i++) {
            if (content[i] === '\n') lineNo++;
        }
        let braceDepth = 0, bodyStart = content.indexOf('{', match.index + match[0].length - 1);
        let bodyEnd = bodyStart, foundFirst = false;
        for (let i = bodyStart; i < content.length; i++) {
            if (content[i] === '{') { braceDepth++; foundFirst = true; }
            if (content[i] === '}') braceDepth--;
            if (foundFirst && braceDepth === 0) { bodyEnd = i; break; }
        }
        steps.push({ stepType, stepText, body: content.substring(bodyStart + 1, bodyEnd).trim(), line: lineNo });
    }
    return steps;
}

function analyzeFile(filepath) {
    const content = fs.readFileSync(filepath, 'utf-8');
    const steps = findStepBlocks(content);
    const issues = [];
    for (const { stepType, stepText, body, line } of steps) {
        const label = stepText || `(${stepType} step)`;
        if (body === '' || body === '// TODO' || body === '/* TODO */') {
            issues.push({ step: label, file: filepath, line, issue: 'EMPTY_BODY', severity: 'FAIL' });
            continue;
        }
        if (TAUTOLOGY_PATTERNS.some(p => p.test(body))) {
            issues.push({ step: label, file: filepath, line, issue: 'TAUTOLOGY', severity: 'FAIL' });
            continue;
        }
        if (stepType === 'then' && !ASSERTION_PATTERNS.some(p => p.test(body))) {
            issues.push({ step: label, file: filepath, line, issue: 'NO_ASSERTION', severity: 'FAIL' });
        }
    }
    return { count: steps.length, issues };
}

function walkDir(dir, extensions) {
    let files = [];
    try {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            const fullPath = path.join(dir, entry.name);
            if (entry.isDirectory()) files = files.concat(walkDir(fullPath, extensions));
            else if (extensions.some(ext => entry.name.endsWith(ext))) files.push(fullPath);
        }
    } catch (e) {}
    return files;
}

const stepDefsDir = process.argv[2];
const lang = process.argv[3] || 'javascript';
const extensions = lang === 'typescript' ? ['.ts', '.tsx'] : ['.js', '.jsx', '.mjs'];
const files = walkDir(stepDefsDir, extensions);
let totalSteps = 0, allIssues = [];
for (const f of files) {
    const { count, issues } = analyzeFile(f);
    totalSteps += count;
    allIssues = allIssues.concat(issues);
}
const failCount = allIssues.filter(i => i.severity === 'FAIL').length;
const result = {
    status: failCount > 0 ? 'BLOCKED' : 'PASS',
    language: lang, parser: 'node',
    total_steps: totalSteps, quality_pass: totalSteps - failCount,
    quality_fail: failCount, details: allIssues
};
console.log(JSON.stringify(result));
'@

    $tmpFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "verify-step-quality-$([guid]::NewGuid().ToString('N').Substring(0,8)).cjs")
    Set-Content -Path $tmpFile -Value $nodeScript -Encoding utf8
    try {
        $result = & node $tmpFile $StepDefsDir $Lang 2>&1
        return $result
    } finally {
        Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# GO ANALYSIS
# =============================================================================

function Invoke-GoAnalysis {
    param([string]$StepDefsDir)

    # Check if go binary is available
    $goAvailable = $false
    try {
        $null = Get-Command go -ErrorAction Stop
        $goAvailable = $true
    } catch { }

    if (-not $goAvailable) {
        return Invoke-RegexFallback -StepDefsDir $StepDefsDir -Language "go"
    }

    # Use regex-based analysis for Go (avoids need for compilable module)
    $totalSteps = 0
    $allIssues = @()

    $goFiles = Get-ChildItem -Path $StepDefsDir -Filter "*.go" -Recurse -ErrorAction SilentlyContinue

    foreach ($file in $goFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $stepMatches = [regex]::Matches($content, '(?m)^\s*s\.(Step|Given|When|Then)\(')
        foreach ($match in $stepMatches) {
            $totalSteps++
            $linesBefore = $content.Substring(0, $match.Index).Split("`n").Count
            $stepText = ""
            $lineContent = ($content.Split("`n"))[$linesBefore - 1]
            $textMatch = [regex]::Match($lineContent, '["`](.*?)["`]')
            if ($textMatch.Success) {
                $stepText = $textMatch.Groups[1].Value
            } else {
                $stepText = "(go step at line $linesBefore)"
            }

            # Check for empty body in the region after the step registration
            $afterRegion = $content.Substring($match.Index, [Math]::Min(500, $content.Length - $match.Index))
            $bodyEmpty = $false
            if ($afterRegion -match 'func\s*\([^)]*\)\s*\{[[:space:]]*\}' -or
                $afterRegion -match 'func\s*\([^)]*\)\s*error\s*\{[\s]*return\s+nil[\s]*\}') {
                $bodyEmpty = $true
            }

            if ($bodyEmpty) {
                $allIssues += @{
                    step = $stepText
                    file = $file.FullName
                    line = $linesBefore
                    issue = "EMPTY_BODY"
                    severity = "FAIL"
                }
            }
        }
    }

    $failCount = ($allIssues | Where-Object { $_.severity -eq "FAIL" }).Count
    $passCount = $totalSteps - $failCount
    $status = if ($failCount -gt 0) { "BLOCKED" } else { "PASS" }

    $result = @{
        status = $status
        language = "go"
        parser = "regex"
        total_steps = $totalSteps
        quality_pass = $passCount
        quality_fail = $failCount
        details = $allIssues
    }

    return ($result | ConvertTo-Json -Depth 5 -Compress)
}

# =============================================================================
# REGEX FALLBACK
# =============================================================================

function Invoke-RegexFallback {
    param(
        [string]$StepDefsDir,
        [string]$Language
    )

    $extensions = ""
    $annotationPattern = ""

    switch ($Language) {
        "java"    { $extensions = "*.java"; $annotationPattern = '@(Given|When|Then)\s*\(' }
        "rust"    { $extensions = "*.rs";   $annotationPattern = '#\[(given|when|then)\(' }
        { $_ -in "csharp","c#" } { $extensions = "*.cs"; $annotationPattern = '\[(Given|When|Then)\s*\(' }
        "python"  { $extensions = "*.py";   $annotationPattern = '@(given|when|then)\s*\(' }
        "go"      { $extensions = "*.go";   $annotationPattern = 's\.(Step|Given|When|Then)\s*\(' }
        { $_ -in "javascript","js" } { $extensions = "*.js"; $annotationPattern = '\b(Given|When|Then)\s*\(' }
        { $_ -in "typescript","ts" } { $extensions = "*.ts"; $annotationPattern = '\b(Given|When|Then)\s*\(' }
        default   { $extensions = "*.*";    $annotationPattern = '(Given|When|Then)\s*\(' }
    }

    $parserNote = "DEGRADED_ANALYSIS: No AST parser available for ${Language}. Using regex heuristics."
    $totalSteps = 0
    $allIssues = @()

    $files = Get-ChildItem -Path $StepDefsDir -Filter $extensions -Recurse -ErrorAction SilentlyContinue

    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $lines = $content.Split("`n")
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $annotationPattern) {
                $totalSteps++
                $lineNo = $i + 1

                # Extract step text
                $stepText = ""
                $textMatch = [regex]::Match($lines[$i], '"([^"]+)"')
                if ($textMatch.Success) {
                    $stepText = $textMatch.Groups[1].Value
                } else {
                    $textMatch = [regex]::Match($lines[$i], "'([^']+)'")
                    if ($textMatch.Success) {
                        $stepText = $textMatch.Groups[1].Value
                    } else {
                        $stepText = "($Language step at line $lineNo)"
                    }
                }

                # Look ahead for empty body
                $bodyRegion = ($lines[$i..([Math]::Min($i + 30, $lines.Count - 1))]) -join "`n"
                $isEmpty = $false

                switch ($Language) {
                    "java" {
                        if ($bodyRegion -match '^\s*\{\s*\}') { $isEmpty = $true }
                    }
                    "python" {
                        if ($bodyRegion -match '(?m)^\s+pass\s*$') { $isEmpty = $true }
                    }
                    default {
                        if ($bodyRegion -match '^\s*\{\s*\}') { $isEmpty = $true }
                    }
                }

                if ($isEmpty) {
                    $allIssues += @{
                        step = $stepText
                        file = $file.FullName
                        line = $lineNo
                        issue = "EMPTY_BODY"
                        severity = "FAIL"
                    }
                }
            }
        }
    }

    $failCount = ($allIssues | Where-Object { $_.severity -eq "FAIL" }).Count
    $passCount = $totalSteps - $failCount
    $status = if ($failCount -gt 0) { "BLOCKED" } else { "PASS" }

    $result = @{
        status = $status
        language = $Language
        parser = "regex"
        parser_note = $parserNote
        total_steps = $totalSteps
        quality_pass = $passCount
        quality_fail = $failCount
        details = $allIssues
    }

    return ($result | ConvertTo-Json -Depth 5 -Compress)
}

# =============================================================================
# MAIN ROUTING
# =============================================================================

$result = ""

switch -Regex ($Language) {
    "^(python|py)$" {
        $result = Invoke-PythonAnalysis -StepDefsDir $StepDefsDir
    }
    "^(javascript|js)$" {
        $result = Invoke-JavaScriptAnalysis -StepDefsDir $StepDefsDir -Lang "javascript"
    }
    "^(typescript|ts)$" {
        $result = Invoke-JavaScriptAnalysis -StepDefsDir $StepDefsDir -Lang "typescript"
    }
    "^(go|golang)$" {
        $result = Invoke-GoAnalysis -StepDefsDir $StepDefsDir
    }
    default {
        $result = Invoke-RegexFallback -StepDefsDir $StepDefsDir -Language $Language
    }
}

# Output
if ($JsonMode) {
    Write-Output $result
} else {
    try {
        $parsed = $result | ConvertFrom-Json
        Write-Host "Step Quality Analysis"
        Write-Host "  Language: $($parsed.language)"
        Write-Host "  Parser:   $($parsed.parser)"
        Write-Host "  Status:   $($parsed.status)"
        Write-Host "  Total:    $($parsed.total_steps) steps"
        Write-Host "  Pass:     $($parsed.quality_pass)"
        Write-Host "  Fail:     $($parsed.quality_fail)"

        if ($parsed.parser_note) {
            Write-Host "  Note:     $($parsed.parser_note)"
        }

        if ($parsed.quality_fail -gt 0) {
            Write-Host ""
            Write-Host "  Issues:"
            foreach ($detail in $parsed.details) {
                Write-Host "    [$($detail.severity)] $($detail.issue): $($detail.step) ($($detail.file):$($detail.line))"
            }
        }
    } catch {
        Write-Output $result
    }
}

# Exit code: 0 for PASS/DEGRADED, non-zero for BLOCKED
try {
    $parsed = $result | ConvertFrom-Json
    if ($parsed.status -eq "BLOCKED") {
        exit 1
    }
} catch { }
exit 0
