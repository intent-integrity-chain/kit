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

# Extract assertion content for hashing
# Accepts: directory path (tests/features/), single .feature file, or legacy test-specs.md
# For .feature files: extracts Given/When/Then/And/But step lines in document order
#   - Files sorted by name for determinism, lines in document order within each file
#   - Whitespace normalized: leading stripped, internal collapsed, trailing stripped
# For test-specs.md (legacy): extracts **Given**:/**When**:/**Then**: lines, sorted
function Get-AssertionContent {
    param([string]$InputPath)

    if (Test-Path -Path $InputPath -PathType Container) {
        # Directory input: glob all .feature files, sorted by name
        $files = Get-ChildItem "$InputPath/*.feature" -ErrorAction SilentlyContinue | Sort-Object Name

        if (-not $files -or $files.Count -eq 0) {
            return ""
        }

        # Extract step lines in document order per file, normalize whitespace
        $allLines = @()
        foreach ($f in $files) {
            $lines = Get-Content $f.FullName | Where-Object { $_ -match '^\s*(Given|When|Then|And|But) ' }
            foreach ($line in $lines) {
                # Normalize: strip leading whitespace, collapse internal whitespace, trim trailing
                $normalized = $line.Trim() -replace '\s{2,}', ' '
                $allLines += $normalized
            }
        }

        return ($allLines -join "`n")
    }
    elseif (Test-Path -Path $InputPath -PathType Leaf) {
        if ($InputPath -like "*.feature") {
            # Single .feature file input
            $content = Get-Content $InputPath
            $allLines = @()
            $lines = $content | Where-Object { $_ -match '^\s*(Given|When|Then|And|But) ' }
            foreach ($line in $lines) {
                $normalized = $line.Trim() -replace '\s{2,}', ' '
                $allLines += $normalized
            }
            return ($allLines -join "`n")
        }
        else {
            # Legacy test-specs.md input: extract **Given**:/**When**:/**Then**: lines
            $content = Get-Content $InputPath
            $assertions = $content | Where-Object { $_ -match '^\*\*(Given|When|Then)\*\*:' } |
                ForEach-Object { $_.TrimEnd() } |
                Sort-Object
            return ($assertions -join "`n")
        }
    }
    else {
        return ""
    }
}

# Compute SHA256 hash of assertion content
# Accepts: directory path (tests/features/), single .feature file, or legacy test-specs.md
# Returns just the hash string, or NO_ASSERTIONS if no step lines found
function Get-AssertionHash {
    param([string]$InputPath)

    $assertions = Get-AssertionContent -InputPath $InputPath

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

# Derive context.json path from input path
# Supports:
#   Directory: tests/features/ -> tests/ -> feature_dir/ -> context.json (2 levels up)
#   .feature file: tests/features/x.feature -> tests/features/ -> tests/ -> feature_dir/ (3 levels up)
#   Legacy .md: tests/test-specs.md -> tests/ -> feature_dir/ -> context.json (2 levels up)
function Get-ContextPath {
    param([string]$InputPath)

    if (Test-Path -Path $InputPath -PathType Container) {
        # Directory input: tests/features/ -> go up 2 levels
        $parentDir = Split-Path $InputPath -Parent       # tests/
        $featureDir = Split-Path $parentDir -Parent       # specs/NNN-feature/
        return Join-Path $featureDir "context.json"
    }
    elseif ($InputPath -like "*.feature") {
        # Single .feature file: tests/features/x.feature -> go up 3 levels
        $featuresDir = Split-Path $InputPath -Parent      # tests/features/
        $testsDir = Split-Path $featuresDir -Parent       # tests/
        $featureDir = Split-Path $testsDir -Parent        # specs/NNN-feature/
        return Join-Path $featureDir "context.json"
    }
    else {
        # Legacy: tests/test-specs.md -> go up 2 levels
        $testsDir = Split-Path $InputPath -Parent         # tests/
        $featureDir = Split-Path $testsDir -Parent        # specs/NNN-feature/
        return Join-Path $featureDir "context.json"
    }
}

# Store assertion hash in context.json
# Creates or updates the testify section
# context.json path is derived from input location (not caller-specified)
# For directory input: stores features_dir and file_count
# For legacy file input: stores test_specs_file (backward compat)
function Set-AssertionHash {
    param(
        [string]$InputPath,
        [string]$ContextFile  # Legacy param — ignored, path is derived
    )
    $ContextFile = Get-ContextPath -InputPath $InputPath

    $hash = Get-AssertionHash -InputPath $InputPath
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    # Create context file if it doesn't exist
    if (-not (Test-Path $ContextFile)) {
        @{} | ConvertTo-Json | Set-Content $ContextFile
    }

    # Read existing context
    $context = Get-Content $ContextFile -Raw | ConvertFrom-Json

    # Build testify data based on input type
    if (Test-Path -Path $InputPath -PathType Container) {
        # Directory input: store features_dir and file_count
        $fileCount = (Get-ChildItem "$InputPath/*.feature" -ErrorAction SilentlyContinue).Count
        $testifyData = @{
            assertion_hash = $hash
            generated_at = $timestamp
            features_dir = $InputPath
            file_count = $fileCount
        }
    }
    else {
        # Legacy file input: store test_specs_file
        $testifyData = @{
            assertion_hash = $hash
            generated_at = $timestamp
            test_specs_file = $InputPath
        }
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
# Returns: "valid", "invalid", or "missing"
# context.json path is derived from input location
function Test-AssertionHash {
    param(
        [string]$InputPath,
        [string]$ContextFile  # Legacy param — ignored, path is derived
    )
    $ContextFile = Get-ContextPath -InputPath $InputPath

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
    $currentHash = Get-AssertionHash -InputPath $InputPath

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
    param([string]$InputPath)

    if (-not (Test-GitRepo)) {
        return "ERROR:NOT_GIT_REPO"
    }

    $hash = Get-AssertionHash -InputPath $InputPath
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    # Create note content
    $noteContent = @"
testify-hash: $hash
generated-at: $timestamp
test-specs-file: $InputPath
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
    param([string]$InputPath)

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
    $currentHash = Get-AssertionHash -InputPath $InputPath

    if ($storedHash -eq $currentHash) {
        return "valid"
    } else {
        return "invalid"
    }
}

# =============================================================================
# GIT DIFF INTEGRITY CHECK
# =============================================================================

# Check if input file has uncommitted assertion changes
function Test-GitDiff {
    param([string]$InputPath)

    if (-not (Test-GitRepo)) {
        return "ERROR:NOT_GIT_REPO"
    }

    if (-not (Test-Path $InputPath)) {
        return "ERROR:FILE_NOT_FOUND"
    }

    # Check if file is tracked by git
    try {
        $null = git ls-files --error-unmatch $InputPath 2>$null
        if ($LASTEXITCODE -ne 0) {
            return "untracked"
        }
    } catch {
        return "untracked"
    }

    # Get diff of the file against HEAD
    try {
        $diffOutput = git diff HEAD -- $InputPath 2>$null
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
# Accepts: features directory, single .feature file, or legacy test-specs.md
# Returns JSON with status from each check method
function Get-ComprehensiveIntegrityCheck {
    param(
        [string]$InputPath,
        [string]$ContextFile,  # Legacy param — ignored, path is derived
        [string]$ConstitutionFile
    )
    $ContextFile = Get-ContextPath -InputPath $InputPath

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
        $hashResult = Test-AssertionHash -InputPath $InputPath -ContextFile $ContextFile
    } else {
        $hashResult = "missing"
    }

    # Check git-based integrity (if in git repo and input is a file)
    # Git note/diff checks only apply to individual files, not directories
    if (Test-GitRepo) {
        if (Test-Path -Path $InputPath -PathType Leaf) {
            $gitNoteResult = Test-GitNote -InputPath $InputPath
            $gitDiffResult = Test-GitDiff -InputPath $InputPath
        } else {
            # For directory input, git note/diff not applicable (multiple files)
            $gitNoteResult = "skipped"
            $gitDiffResult = "skipped"
        }
    }

    # Determine overall status
    if ($hashResult -eq "invalid" -or $gitNoteResult -eq "invalid") {
        $overallStatus = "BLOCKED"
        $blockReason = "Assertions were modified since testify ran"
    } elseif ($gitDiffResult -eq "modified") {
        $overallStatus = "BLOCKED"
        $blockReason = "Uncommitted changes to assertions detected"
    } elseif ($tddDetermination -eq "mandatory") {
        if ($hashResult -eq "missing" -and $gitNoteResult -ne "valid") {
            $overallStatus = "BLOCKED"
            $blockReason = "TDD is mandatory but no integrity hash found"
        } else {
            $overallStatus = "PASS"
        }
    } else {
        if ($hashResult -eq "valid" -or $gitNoteResult -eq "valid") {
            $overallStatus = "PASS"
        } elseif ($hashResult -eq "missing" -and $gitNoteResult -ne "valid") {
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
            Write-Error "Usage: testify-tdd.ps1 extract-assertions <features-dir-or-file>"
            exit 1
        }
        Get-AssertionContent -InputPath $FilePath
    }
    "compute-hash" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 compute-hash <features-dir-or-file>"
            exit 1
        }
        Get-AssertionHash -InputPath $FilePath
    }
    { $_ -in "store-hash", "rehash" } {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 store-hash <features-dir-or-file>"
            exit 1
        }
        Set-AssertionHash -InputPath $FilePath
    }
    "verify-hash" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 verify-hash <features-dir-or-file>"
            exit 1
        }
        Test-AssertionHash -InputPath $FilePath
    }
    "store-git-note" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 store-git-note <test-specs-file>"
            exit 1
        }
        Set-GitNote -InputPath $FilePath
    }
    "verify-git-note" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 verify-git-note <test-specs-file>"
            exit 1
        }
        Test-GitNote -InputPath $FilePath
    }
    "check-git-diff" {
        if (-not $FilePath) {
            Write-Error "Usage: testify-tdd.ps1 check-git-diff <test-specs-file>"
            exit 1
        }
        Test-GitDiff -InputPath $FilePath
    }
    "comprehensive-check" {
        if (-not $FilePath -or -not $ContextFile) {
            Write-Error "Usage: testify-tdd.ps1 comprehensive-check <features-dir-or-file> <constitution-file>"
            exit 1
        }
        Get-ComprehensiveIntegrityCheck -InputPath $FilePath -ConstitutionFile $ContextFile
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
        Write-Host "  Hash-based Integrity (context.json auto-derived from input path):"
        Write-Host "    extract-assertions <dir-or-file>      - Extract step lines (.feature dir/file or legacy .md)"
        Write-Host "    compute-hash <dir-or-file>            - Compute SHA256 hash"
        Write-Host "    store-hash|rehash <dir-or-file>       - Atomic compute + store hash in feature's context.json"
        Write-Host "    verify-hash <dir-or-file>             - Verify against feature's context.json"
        Write-Host "  Git-based Integrity (tamper-resistant):"
        Write-Host "    store-git-note <test-specs-file>      - Store hash as git note"
        Write-Host "    verify-git-note <test-specs-file>     - Verify against git note"
        Write-Host "    check-git-diff <test-specs-file>      - Check uncommitted changes"
        Write-Host "  Comprehensive:"
        Write-Host "    comprehensive-check <dir-or-file> <constitution-file>"
        exit 1
    }
}
