#!/usr/bin/env pwsh
# IIKIT-POST-COMMIT
# Git post-commit hook for tamper-resistant assertion hash storage (PowerShell)
# Stores assertion hashes as git notes when test-specs.md is committed
#
# This script provides PowerShell parity for CI or direct PowerShell invocation.
# The actual .git/hooks/post-commit is always bash (git invokes hooks via sh).
#
# Usage: pwsh post-commit-hook.ps1

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
    exit 0
}

$testifyScript = Join-Path $scriptsDir "testify-tdd.ps1"

# ============================================================================
# FAST PATH — exit if no test-specs.md in the commit that just landed
# ============================================================================

$committedFiles = git diff-tree --no-commit-id --name-only -r HEAD 2>$null
$committedTestSpecs = $committedFiles | Where-Object { $_ -match 'test-specs\.md$' }

if (-not $committedTestSpecs) {
    exit 0
}

# ============================================================================
# STORE GIT NOTES — for each committed test-specs.md
# ============================================================================

# Preserve any existing note content (from a previous testify on this commit)
$existingNote = ""
try {
    $existingNote = git notes --ref="refs/notes/testify" show HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { $existingNote = "" }
} catch { $existingNote = "" }
$fullNote = $existingNote

foreach ($committedPath in $committedTestSpecs) {
    if ([string]::IsNullOrEmpty($committedPath)) { continue }

    # Get the committed version from HEAD
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        $committedContent = git show "HEAD:$committedPath" 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($committedContent)) {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
            continue
        }
        $committedContent | Out-File -FilePath $tempFile -Encoding utf8
    } catch {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
        continue
    }

    # Compute hash of the committed version
    $currentHash = & $testifyScript compute-hash $tempFile
    Remove-Item $tempFile -ErrorAction SilentlyContinue

    # Skip if no assertions
    if ($currentHash -eq "NO_ASSERTIONS") {
        continue
    }

    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $entry = "testify-hash: $currentHash`ngenerated-at: $timestamp`ntest-specs-file: $committedPath"

    # Remove any existing entry for this same file
    if (-not [string]::IsNullOrEmpty($fullNote)) {
        $lines = $fullNote -split "`n"
        $filtered = @()
        $skip = $false
        $currentBlock = @()
        foreach ($line in $lines) {
            if ($line -match '^testify-hash:') {
                if ($currentBlock.Count -gt 0 -and -not $skip) {
                    $filtered += $currentBlock
                }
                $currentBlock = @($line)
                $skip = $false
            } elseif ($line -eq '---') {
                if (-not $skip) {
                    $currentBlock += $line
                    $filtered += $currentBlock
                }
                $currentBlock = @()
                $skip = $false
            } else {
                if ($line -match "^test-specs-file:.*$([regex]::Escape($committedPath))") {
                    $skip = $true
                }
                $currentBlock += $line
            }
        }
        if ($currentBlock.Count -gt 0 -and -not $skip) {
            $filtered += $currentBlock
        }
        $fullNote = ($filtered -join "`n").Trim()
    }

    # Append new entry
    if (-not [string]::IsNullOrEmpty($fullNote)) {
        $fullNote = "$fullNote`n---`n$entry"
    } else {
        $fullNote = $entry
    }

    Write-Host "[iikit] Assertion hash stored as git note for $committedPath" -ForegroundColor Green
}

# Write the accumulated note
if (-not [string]::IsNullOrEmpty($fullNote)) {
    try {
        $fullNote | git notes --ref="refs/notes/testify" add -f -F - HEAD 2>$null
    } catch {
        # Git notes failed — not critical, continue
    }
}

exit 0
