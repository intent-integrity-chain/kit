#!/usr/bin/env pwsh
# IIKIT-PRE-COMMIT
# Git pre-commit hook for assertion integrity enforcement (PowerShell)
# Prevents committing tampered test-specs.md assertions
#
# This script provides PowerShell parity for CI or direct PowerShell invocation.
# The actual .git/hooks/pre-commit is always bash (git invokes hooks via sh).
#
# Usage: pwsh pre-commit-hook.ps1

$ErrorActionPreference = "Stop"

# ============================================================================
# PATH DETECTION — find the scripts directory at runtime
# ============================================================================

try {
    $repoRoot = (git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($repoRoot)) {
        exit 0
    }
} catch {
    exit 0
}

$scriptsDir = $null
$candidatePaths = @(
    (Join-Path $repoRoot ".claude/skills/iikit-core/scripts/powershell"),
    (Join-Path $repoRoot ".tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell"),
    (Join-Path $repoRoot ".codex/skills/iikit-core/scripts/powershell")
)

foreach ($candidate in $candidatePaths) {
    if (Test-Path (Join-Path $candidate "testify-tdd.ps1")) {
        $scriptsDir = $candidate
        break
    }
}

if (-not $scriptsDir) {
    Write-Warning "[iikit] IIKit scripts not found - skipping assertion integrity check"
    exit 0
}

$testifyScript = Join-Path $scriptsDir "testify-tdd.ps1"

# ============================================================================
# FAST PATH — exit immediately if no test-specs.md is staged
# ============================================================================

$stagedFiles = git diff --cached --name-only 2>$null
$stagedTestSpecs = $stagedFiles | Where-Object { $_ -match 'test-specs\.md$' }

if (-not $stagedTestSpecs) {
    exit 0
}

# ============================================================================
# TDD DETERMINATION — check constitution for TDD requirements
# ============================================================================

$constitutionFile = Join-Path $repoRoot "CONSTITUTION.md"
$tddDetermination = "unknown"
if (Test-Path $constitutionFile) {
    $tddDetermination = & $testifyScript get-tdd-determination $constitutionFile
}

# ============================================================================
# CONTEXT FILE — read stored hashes
# ============================================================================

# ============================================================================
# SLOW PATH — verify each staged test-specs.md
# ============================================================================

$blocked = $false
$blockMessages = @()

# Capture all staged files once for context.json co-staging detection
$allStagedFiles = git diff --cached --name-only 2>$null

foreach ($stagedPath in $stagedTestSpecs) {
    if ([string]::IsNullOrEmpty($stagedPath)) { continue }

    # Derive per-feature context.json path from the test-specs.md path
    # test-specs.md is at specs/NNN-feature/tests/test-specs.md
    # context.json is at specs/NNN-feature/context.json
    $testsDir = Split-Path $stagedPath -Parent          # specs/NNN-feature/tests
    $featureDir = Split-Path $testsDir -Parent           # specs/NNN-feature
    $contextRelPath = Join-Path $featureDir "context.json"  # specs/NNN-feature/context.json
    $contextFile = Join-Path $repoRoot $contextRelPath

    # Check if this feature's context.json is also being staged
    $contextStaged = $allStagedFiles | Where-Object { $_ -eq $contextRelPath -or $_ -eq ($contextRelPath -replace '\\', '/') }

    # Extract staged version to a temp file (check what's being committed)
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        $stagedContent = git show ":$stagedPath" 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($stagedContent)) {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
            continue
        }
        $stagedContent | Out-File -FilePath $tempFile -Encoding utf8
    } catch {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
        continue
    }

    # Compute hash of the staged version
    $currentHash = & $testifyScript compute-hash $tempFile
    Remove-Item $tempFile -ErrorAction SilentlyContinue

    # Skip if no assertions in the file
    if ($currentHash -eq "NO_ASSERTIONS") {
        continue
    }

    # Check against context.json
    # When staged (testify commit): read working tree. When NOT staged: read
    # committed version from HEAD to prevent working-tree forgery (A8b attack).
    $contextStatus = "missing"
    $contextJson = $null
    if ($contextStaged -and (Test-Path $contextFile)) {
        # Testify commit: read working tree (testify just wrote it)
        $contextJson = Get-Content $contextFile -Raw -ErrorAction SilentlyContinue
    } else {
        # Not staged: read committed version from HEAD (tamper-resistant)
        try {
            $contextJson = git show "HEAD:$($contextRelPath -replace '\\', '/')" 2>$null
            if ($LASTEXITCODE -ne 0) { $contextJson = $null }
        } catch { $contextJson = $null }
    }

    if (-not [string]::IsNullOrEmpty($contextJson)) {
        try {
            $context = $contextJson | ConvertFrom-Json

            if ($context.testify -and $context.testify.assertion_hash) {
                $storedFile = $context.testify.test_specs_file
                $storedHash = $context.testify.assertion_hash

                # Match by path: stored file must end with the staged path
                if ($storedFile -eq $stagedPath -or $storedFile.EndsWith("/$stagedPath")) {
                    if ($storedHash -eq $currentHash) {
                        $contextStatus = "valid"
                    } else {
                        $contextStatus = "invalid"
                    }
                }
            }
        } catch {
            # Invalid JSON or missing fields — treat as missing
        }
    }

    # Check git notes (tamper-resistant)
    # Search backward through recent commits to find the most recent testify note
    # that matches THIS specific test-specs.md file (by path).
    # Notes may contain multiple entries (separated by ---) for multi-feature commits.
    $noteStatus = "missing"
    $noteHash = $null
    try {
        $recentCommits = git rev-list HEAD -50 2>$null
        if ($recentCommits) {
            foreach ($commitSha in ($recentCommits -split "`n")) {
                if ([string]::IsNullOrEmpty($commitSha)) { continue }
                $noteContent = git notes --ref="refs/notes/testify" show $commitSha 2>$null
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($noteContent)) {
                    # Parse multi-entry notes: split by --- and find matching file
                    $entries = ($noteContent -join "`n") -split '---'
                    foreach ($entry in $entries) {
                        $entryLines = $entry.Trim() -split "`n"
                        $entryFile = ""
                        $entryHash = ""
                        foreach ($line in $entryLines) {
                            if ($line -match '^test-specs-file:\s*(.+)') { $entryFile = $Matches[1].Trim() }
                            if ($line -match '^testify-hash:\s*(.+)') { $entryHash = $Matches[1].Trim() }
                        }
                        if ($entryFile -eq $stagedPath -or $entryFile.EndsWith("/$stagedPath")) {
                            $noteHash = $entryHash
                            break
                        }
                    }
                    if (-not [string]::IsNullOrEmpty($noteHash)) { break }
                    # Note exists but no matching file — keep searching older commits
                }
            }
        }
    } catch {
        # Git notes not available — stay missing
    }
    if (-not [string]::IsNullOrEmpty($noteHash)) {
        if ($noteHash -eq $currentHash) {
            $noteStatus = "valid"
        } else {
            $noteStatus = "invalid"
        }
    }

    # Combine results
    # When context.json is staged alongside test-specs.md and hashes match,
    # this is a testify commit (new/updated assertions with fresh hash).
    # The old git note from a previous testify run is expected to not match.
    # When context.json is NOT staged, git note "invalid" overrides context "valid".
    $hashStatus = "missing"
    if ($contextStaged -and $contextStatus -eq "valid") {
        # Testify commit: context.json staged with matching hash -> trust it
        $hashStatus = "valid"
    } elseif ($noteStatus -eq "invalid" -or $contextStatus -eq "invalid") {
        $hashStatus = "invalid"
    } elseif ($noteStatus -eq "valid" -or $contextStatus -eq "valid") {
        $hashStatus = "valid"
    }

    # Decision logic
    switch ($hashStatus) {
        "valid" {
            # PASS — silent
        }
        "invalid" {
            $blocked = $true
            $blockMessages += "BLOCKED: $stagedPath - assertion integrity check failed"
            $blockMessages += "  Assertions have been modified since /iikit-05-testify generated them."
            $blockMessages += "  Re-run /iikit-05-testify to regenerate test specifications."
        }
        "missing" {
            if ($tddDetermination -eq "mandatory") {
                Write-Warning "[iikit] $stagedPath - no stored assertion hash found (TDD is mandatory)"
                Write-Warning "[iikit]   If this is the initial testify commit, this is expected."
                Write-Warning "[iikit]   Otherwise, run /iikit-05-testify to generate integrity hashes."
            }
            # Allow in both cases
        }
    }
}

# ============================================================================
# OUTPUT — report results
# ============================================================================

if ($blocked) {
    Write-Host ""
    Write-Host "+---------------------------------------------------------+" -ForegroundColor Red
    Write-Host "|  IIKIT PRE-COMMIT: ASSERTION INTEGRITY CHECK FAILED     |" -ForegroundColor Red
    Write-Host "+---------------------------------------------------------+" -ForegroundColor Red
    Write-Host ""
    foreach ($msg in $blockMessages) {
        Write-Host "[iikit] $msg" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "[iikit] To fix: Re-run /iikit-05-testify to regenerate test specs with valid hashes." -ForegroundColor Yellow
    Write-Host "[iikit] To bypass (NOT recommended): git commit --no-verify" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

exit 0
