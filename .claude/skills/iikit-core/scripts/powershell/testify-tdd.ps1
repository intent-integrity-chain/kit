# TDD Assessment and Test Generation Helper for Testify Skill
# This script provides utilities for the testify skill

param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$FilePath,

    [Parameter(Position = 2)]
    [string]$ContextFile,

    [Parameter(Position = 3)]
    [string]$ConstitutionFile
)

$ErrorActionPreference = "Stop"

# =============================================================================
# TDD ASSESSMENT FUNCTIONS
# =============================================================================

function Get-TddAssessment {
    param([string]$ConstitutionFile)

    if (-not (Test-Path $ConstitutionFile)) {
        return @{
            error = "Constitution file not found"
        } | ConvertTo-Json
    }

    $content = Get-Content $ConstitutionFile -Raw

    # Initialize assessment
    $determination = "optional"
    $confidence = "high"
    $evidence = ""
    $reasoning = "No TDD indicators found in constitution"

    # Check for strong TDD indicators with MUST/REQUIRED
    if ($content -match "MUST.*(TDD|test-first|red-green-refactor|write tests before)") {
        $determination = "mandatory"
        $confidence = "high"
        $evidence = $Matches[0]
        $reasoning = "Strong TDD indicator found with MUST modifier"
    }
    elseif ($content -match "(TDD|test-first|red-green-refactor|write tests before).*MUST") {
        $determination = "mandatory"
        $confidence = "high"
        $evidence = $Matches[0]
        $reasoning = "Strong TDD indicator found with MUST modifier"
    }
    # Check for moderate indicators
    elseif ($content -match "MUST.*(test-driven|tests.*before.*code|tests.*before.*implementation)") {
        $determination = "mandatory"
        $confidence = "medium"
        $evidence = $Matches[0]
        $reasoning = "Moderate TDD indicator found with MUST modifier"
    }
    # Check for prohibition indicators (both word orders)
    elseif ($content -match "MUST.*(test-after|integration tests only|no unit tests)") {
        $determination = "forbidden"
        $confidence = "high"
        $evidence = $Matches[0]
        $reasoning = "TDD prohibition indicator found"
    }
    elseif ($content -match "(test-after|integration tests only|no unit tests).*MUST") {
        $determination = "forbidden"
        $confidence = "high"
        $evidence = $Matches[0]
        $reasoning = "TDD prohibition indicator found"
    }
    # Check for implicit indicators (SHOULD)
    elseif ($content -match "SHOULD.*(quality gates|coverage|test)") {
        $determination = "optional"
        $confidence = "low"
        $evidence = $Matches[0]
        $reasoning = "Implicit testing indicator found with SHOULD modifier"
    }

    return @{
        determination = $determination
        confidence    = $confidence
        evidence      = $evidence
        reasoning     = $reasoning
    } | ConvertTo-Json
}

# =============================================================================
# ASSERTION INTEGRITY FUNCTIONS
# =============================================================================

# Extract assertion content from test-specs.md for hashing
# Extracts ONLY the Given/When/Then lines which contain expected values
# Output is sorted and normalized for deterministic hashing
function Get-AssertionContent {
    param([string]$TestSpecsFile)

    if (-not (Test-Path $TestSpecsFile)) {
        return ""
    }

    $content = Get-Content $TestSpecsFile

    # Extract Given/When/Then lines, trim whitespace, sort for determinism
    $assertions = $content | Where-Object { $_ -match '^\*\*(Given|When|Then)\*\*:' } |
        ForEach-Object { $_.TrimEnd() } |
        Sort-Object

    return ($assertions -join "`n")
}

# Compute SHA256 hash of assertion content
function Get-AssertionHash {
    param([string]$TestSpecsFile)

    $assertions = Get-AssertionContent -TestSpecsFile $TestSpecsFile

    if ([string]::IsNullOrEmpty($assertions)) {
        return "NO_ASSERTIONS"
    }

    # Compute SHA256 hash
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($assertions)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash($bytes)
    $hash = [BitConverter]::ToString($hashBytes) -replace '-', ''

    return $hash.ToLower()
}

# Derive context.json path from test-specs.md path
# test-specs.md lives at specs/NNN-feature/tests/test-specs.md
# context.json lives at specs/NNN-feature/context.json
function Get-ContextPath {
    param([string]$TestSpecsFile)
    $testsDir = Split-Path $TestSpecsFile -Parent    # specs/NNN-feature/tests
    $featureDir = Split-Path $testsDir -Parent        # specs/NNN-feature
    return Join-Path $featureDir "context.json"
}

# Store assertion hash in context.json
# context.json path is derived from test-specs.md location (not caller-specified)
function Set-AssertionHash {
    param(
        [string]$TestSpecsFile,
        [string]$ContextFile  # Legacy param — ignored, path is derived
    )
    $ContextFile = Get-ContextPath -TestSpecsFile $TestSpecsFile

    $hash = Get-AssertionHash -TestSpecsFile $TestSpecsFile
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    # Create context file if it doesn't exist
    if (-not (Test-Path $ContextFile)) {
        @{} | ConvertTo-Json | Set-Content $ContextFile
    }

    # Read existing context
    $context = Get-Content $ContextFile -Raw | ConvertFrom-Json

    # Add or update testify section
    $testifyData = @{
        assertion_hash = $hash
        generated_at = $timestamp
        test_specs_file = $TestSpecsFile
    }

    # Handle PSCustomObject conversion
    if ($context -is [PSCustomObject]) {
        $context | Add-Member -NotePropertyName "testify" -NotePropertyValue $testifyData -Force
    } else {
        $context = @{ testify = $testifyData }
    }

    $context | ConvertTo-Json -Depth 10 | Set-Content $ContextFile

    return $hash
}

# Verify assertion hash matches stored value
# context.json path is derived from test-specs.md location
function Test-AssertionHash {
    param(
        [string]$TestSpecsFile,
        [string]$ContextFile  # Legacy param — ignored, path is derived
    )
    $ContextFile = Get-ContextPath -TestSpecsFile $TestSpecsFile

    # Check if context file exists
    if (-not (Test-Path $ContextFile)) {
        return "missing"
    }

    # Read context
    $context = Get-Content $ContextFile -Raw | ConvertFrom-Json

    # Check if testify section exists
    if (-not $context.testify -or -not $context.testify.assertion_hash) {
        return "missing"
    }

    $storedHash = $context.testify.assertion_hash

    # Compute current hash
    $currentHash = Get-AssertionHash -TestSpecsFile $TestSpecsFile

    if ($storedHash -eq $currentHash) {
        return "valid"
    } else {
        return "invalid"
    }
}

# =============================================================================
# GIT-BASED INTEGRITY FUNCTIONS (Tamper-Resistant)
# =============================================================================

$GIT_NOTES_REF = "refs/notes/testify"

# Check if we're in a git repository
function Test-GitRepo {
    try {
        $null = git rev-parse --git-dir 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Store assertion hash as a git note on the current HEAD
function Set-GitNote {
    param([string]$TestSpecsFile)

    if (-not (Test-GitRepo)) {
        return "ERROR:NOT_GIT_REPO"
    }

    $hash = Get-AssertionHash -TestSpecsFile $TestSpecsFile
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    # Create note content
    $noteContent = @"
testify-hash: $hash
generated-at: $timestamp
test-specs-file: $TestSpecsFile
"@

    # Store as git note on HEAD
    try {
        $noteContent | git notes --ref=$GIT_NOTES_REF add -f -F - HEAD 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $hash
        } else {
            return "ERROR:GIT_NOTE_FAILED"
        }
    } catch {
        return "ERROR:GIT_NOTE_FAILED"
    }
}

# Verify assertion hash against git note
function Test-GitNote {
    param([string]$TestSpecsFile)

    if (-not (Test-GitRepo)) {
        return "ERROR:NOT_GIT_REPO"
    }

    # Get the git note for HEAD
    try {
        $noteContent = git notes --ref=$GIT_NOTES_REF show HEAD 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($noteContent)) {
            return "missing"
        }
    } catch {
        return "missing"
    }

    # Extract hash from note
    $storedHash = ($noteContent | Where-Object { $_ -match '^testify-hash:' }) -replace '^testify-hash:\s*', ''

    if ([string]::IsNullOrEmpty($storedHash)) {
        return "missing"
    }

    # Compute current hash
    $currentHash = Get-AssertionHash -TestSpecsFile $TestSpecsFile

    if ($storedHash -eq $currentHash) {
        return "valid"
    } else {
        return "invalid"
    }
}

# =============================================================================
# GIT DIFF INTEGRITY CHECK
# =============================================================================

# Check if test-specs.md has uncommitted assertion changes
function Test-GitDiff {
    param([string]$TestSpecsFile)

    if (-not (Test-GitRepo)) {
        return "ERROR:NOT_GIT_REPO"
    }

    if (-not (Test-Path $TestSpecsFile)) {
        return "ERROR:FILE_NOT_FOUND"
    }

    # Check if file is tracked by git
    try {
        $null = git ls-files --error-unmatch $TestSpecsFile 2>$null
        if ($LASTEXITCODE -ne 0) {
            return "untracked"
        }
    } catch {
        return "untracked"
    }

    # Get diff of the file against HEAD
    try {
        $diffOutput = git diff HEAD -- $TestSpecsFile 2>$null
        if ($LASTEXITCODE -ne 0) {
            return "ERROR:GIT_DIFF_FAILED"
        }
    } catch {
        return "ERROR:GIT_DIFF_FAILED"
    }

    # If no diff at all, file is clean
    if ([string]::IsNullOrEmpty($diffOutput)) {
        return "clean"
    }

    # Check if any Given/When/Then lines were modified
    if ($diffOutput -match '^[+-]\*\*(Given|When|Then)\*\*:') {
        return "modified"
    } else {
        return "clean"
    }
}

# Comprehensive integrity check combining all methods
function Get-ComprehensiveIntegrityCheck {
    param(
        [string]$TestSpecsFile,
        [string]$ContextFile,  # Legacy param — ignored, path is derived
        [string]$ConstitutionFile
    )
    $ContextFile = Get-ContextPath -TestSpecsFile $TestSpecsFile

    $hashResult = "skipped"
    $gitNoteResult = "skipped"
    $gitDiffResult = "skipped"
    $tddDetermination = "unknown"
    $overallStatus = "unknown"
    $blockReason = ""

    # Get TDD determination from constitution
    if (Test-Path $ConstitutionFile) {
        $tddJson = Get-TddAssessment -ConstitutionFile $ConstitutionFile | ConvertFrom-Json
        $tddDetermination = $tddJson.determination
        if ([string]::IsNullOrEmpty($tddDetermination)) {
            $tddDetermination = "unknown"
        }
    }

    # Check context.json hash
    if (Test-Path $ContextFile) {
        $hashResult = Test-AssertionHash -TestSpecsFile $TestSpecsFile -ContextFile $ContextFile
    } else {
        $hashResult = "missing"
    }

    # Check git-based integrity (if in git repo)
    if (Test-GitRepo) {
        $gitNoteResult = Test-GitNote -TestSpecsFile $TestSpecsFile
        $gitDiffResult = Test-GitDiff -TestSpecsFile $TestSpecsFile
    }

    # Determine overall status
    if ($hashResult -eq "invalid" -or $gitNoteResult -eq "invalid") {
        $overallStatus = "BLOCKED"
        $blockReason = "Assertions were modified since testify ran"
    } elseif ($gitDiffResult -eq "modified") {
        $overallStatus = "BLOCKED"
        $blockReason = "Uncommitted changes to assertions detected"
    } elseif ($tddDetermination -eq "mandatory") {
        if ($hashResult -eq "missing" -and $gitNoteResult -eq "missing") {
            $overallStatus = "BLOCKED"
            $blockReason = "TDD is mandatory but no integrity hash found"
        } else {
            $overallStatus = "PASS"
        }
    } else {
        if ($hashResult -eq "valid" -or $gitNoteResult -eq "valid") {
            $overallStatus = "PASS"
        } elseif ($hashResult -eq "missing" -and $gitNoteResult -eq "missing") {
            $overallStatus = "WARN"
            $blockReason = "No integrity hash found (TDD is optional)"
        } else {
            $overallStatus = "PASS"
        }
    }

    return @{
        overall_status = $overallStatus
        block_reason = $blockReason
        tdd_determination = $tddDetermination
        checks = @{
            context_hash = $hashResult
            git_note = $gitNoteResult
            git_diff = $gitDiffResult
        }
    } | ConvertTo-Json -Depth 3
}

# Get TDD determination only
function Get-TddDetermination {
    param([string]$ConstitutionFile)

    if (-not (Test-Path $ConstitutionFile)) {
        return "unknown"
    }

    $tddJson = Get-TddAssessment -ConstitutionFile $ConstitutionFile | ConvertFrom-Json
    $determination = $tddJson.determination
    if ([string]::IsNullOrEmpty($determination)) {
        return "unknown"
    }
    return $determination
}

# =============================================================================
# TEST SPEC GENERATION FUNCTIONS
# =============================================================================

function Get-AcceptanceScenarioCount {
    param([string]$SpecFile)

    if (-not (Test-Path $SpecFile)) {
        return 0
    }

    $content = Get-Content $SpecFile -Raw

    # Remove HTML comments before counting
    $content = $content -replace '<!--.*?-->', ''

    $patterns = @(
        "\*\*Given\*\*",
        "\*\*When\*\*"
    )

    $count = 0
    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $count += $matches.Count
    }

    return $count
}

function Test-HasAcceptanceScenarios {
    param([string]$SpecFile)

    $count = Get-AcceptanceScenarioCount -SpecFile $SpecFile
    return ($count -gt 0).ToString().ToLower()
}

# =============================================================================
# MAIN
# =============================================================================

switch ($Command) {
    "assess-tdd" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 assess-tdd <constitution-file>"
            exit 1
        }
        Get-TddAssessment -ConstitutionFile $FilePath
    }
    "get-tdd-determination" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 get-tdd-determination <constitution-file>"
            exit 1
        }
        Get-TddDetermination -ConstitutionFile $FilePath
    }
    "count-scenarios" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 count-scenarios <spec-file>"
            exit 1
        }
        Get-AcceptanceScenarioCount -SpecFile $FilePath
    }
    "has-scenarios" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 has-scenarios <spec-file>"
            exit 1
        }
        Test-HasAcceptanceScenarios -SpecFile $FilePath
    }
    "extract-assertions" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 extract-assertions <test-specs-file>"
            exit 1
        }
        Get-AssertionContent -TestSpecsFile $FilePath
    }
    "compute-hash" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 compute-hash <test-specs-file>"
            exit 1
        }
        Get-AssertionHash -TestSpecsFile $FilePath
    }
    "store-hash" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 store-hash <test-specs-file>"
            exit 1
        }
        Set-AssertionHash -TestSpecsFile $FilePath
    }
    "verify-hash" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 verify-hash <test-specs-file>"
            exit 1
        }
        Test-AssertionHash -TestSpecsFile $FilePath
    }
    "store-git-note" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 store-git-note <test-specs-file>"
            exit 1
        }
        Set-GitNote -TestSpecsFile $FilePath
    }
    "verify-git-note" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 verify-git-note <test-specs-file>"
            exit 1
        }
        Test-GitNote -TestSpecsFile $FilePath
    }
    "check-git-diff" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 check-git-diff <test-specs-file>"
            exit 1
        }
        Test-GitDiff -TestSpecsFile $FilePath
    }
    "comprehensive-check" {
        if (-not $FilePath -or -not $ContextFile) {
            Write-Error "Usage: testify-tdd.ps1 comprehensive-check <test-specs-file> <constitution-file>"
            exit 1
        }
        Get-ComprehensiveIntegrityCheck -TestSpecsFile $FilePath -ConstitutionFile $ContextFile
    }
    default {
        Write-Host "Unknown command: $Command"
        Write-Host ""
        Write-Host "Available commands:"
        Write-Host "  TDD Assessment:"
        Write-Host "    assess-tdd <constitution-file>        - Full TDD assessment (JSON)"
        Write-Host "    get-tdd-determination <constitution>  - Just the determination"
        Write-Host "  Scenario Counting:"
        Write-Host "    count-scenarios <spec-file>           - Count acceptance scenarios"
        Write-Host "    has-scenarios <spec-file>             - Check if scenarios exist"
        Write-Host "  Hash-based Integrity (context.json auto-derived from test-specs path):"
        Write-Host "    extract-assertions <test-specs-file>  - Extract assertion lines"
        Write-Host "    compute-hash <test-specs-file>        - Compute SHA256 hash"
        Write-Host "    store-hash <test-specs-file>          - Store hash in feature's context.json"
        Write-Host "    verify-hash <test-specs-file>         - Verify against feature's context.json"
        Write-Host "  Git-based Integrity (tamper-resistant):"
        Write-Host "    store-git-note <test-specs-file>      - Store hash as git note"
        Write-Host "    verify-git-note <test-specs-file>     - Verify against git note"
        Write-Host "    check-git-diff <test-specs-file>      - Check uncommitted changes"
        Write-Host "  Comprehensive:"
        Write-Host "    comprehensive-check <test-specs-file> <constitution-file>"
        exit 1
    }
}
