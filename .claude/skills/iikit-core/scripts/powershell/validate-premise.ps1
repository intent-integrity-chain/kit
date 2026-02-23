#!/usr/bin/env pwsh
# Validate PREMISE.md exists and has all required sections with real content.
# Usage: validate-premise.ps1 [-Json] [ProjectPath]
#
# Required sections: What, Who, Why, Domain, Scope
# Fails if any section is missing, empty, or contains [PLACEHOLDER] tokens.
#
# Exit codes:
#   0 - PASS (all sections present and filled)
#   1 - FAIL (missing file, missing sections, placeholders, or empty sections)

[CmdletBinding()]
param(
    [switch]$Json,
    [Parameter(Position = 0)]
    [string]$ProjectPath,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# Show help if requested
if ($Help) {
    Write-Output @"
Usage: validate-premise.ps1 [-Json] [ProjectPath]

Validates PREMISE.md exists at project root and contains all 5 required
sections (What, Who, Why, Domain, Scope) with non-placeholder content.

Options:
  -Json           Output results as JSON
  ProjectPath     Path to project root (default: git repo root)
  -Help           Show this help message

Exit codes:
  0  PASS - all sections present and filled
  1  FAIL - missing file, missing sections, placeholders, or empty sections
"@
    exit 0
}

# Source common functions
. "$PSScriptRoot/common.ps1"

# =============================================================================
# DETERMINE PROJECT ROOT
# =============================================================================

if ($ProjectPath) {
    $repoRoot = $ProjectPath
} else {
    $repoRoot = Get-RepoRoot
}

$premiseFile = Join-Path $repoRoot 'PREMISE.md'

# =============================================================================
# REQUIRED SECTIONS
# =============================================================================

$requiredSections = @('What', 'Who', 'Why', 'Domain', 'Scope')

# =============================================================================
# VALIDATION
# =============================================================================

$status = 'PASS'
$missingSections = @()
$emptySections = @()
$details = @()
$placeholdersRemaining = 0
$sectionsFound = 0

# Check file existence
if (-not (Test-Path $premiseFile)) {
    $status = 'FAIL'
    $details += "PREMISE.md not found at $premiseFile"

    if ($Json) {
        $result = [ordered]@{
            status                = 'FAIL'
            sections_found        = 0
            sections_required     = $requiredSections.Count
            placeholders_remaining = 0
            missing_sections      = $requiredSections
            details               = $details
        }
        Write-Output ($result | ConvertTo-Json -Compress)
    } else {
        Write-Error "FAIL: PREMISE.md not found at $premiseFile"
        Write-Host "Run /iikit-core init to create one."
    }
    exit 1
}

# Read file content
$premiseContent = Get-Content -Path $premiseFile -ErrorAction SilentlyContinue
$premiseRaw = Get-Content -Path $premiseFile -Raw -ErrorAction SilentlyContinue

# Check for placeholder tokens: match [WORD] patterns (brackets with uppercase/underscore content)
foreach ($line in $premiseContent) {
    $matches = [regex]::Matches($line, '\[[A-Z][A-Z_]*\]')
    $placeholdersRemaining += $matches.Count
}

if ($placeholdersRemaining -gt 0) {
    $status = 'FAIL'
    $details += "Found $placeholdersRemaining unresolved placeholder(s)"
}

# Check each required section
foreach ($section in $requiredSections) {
    # Look for ## Section heading (case-insensitive)
    $headingPattern = "(?mi)^##\s*$section"
    if ($premiseRaw -notmatch $headingPattern) {
        $missingSections += $section
        $status = 'FAIL'
        $details += "Missing required section: $section"
        continue
    }

    $sectionsFound++

    # Extract content between this heading and the next heading (or EOF)
    $sectionPattern = "(?msi)^##\s*$section\s*\r?\n(.*?)(?=^##\s|\z)"
    if ($premiseRaw -match $sectionPattern) {
        $sectionContent = $Matches[1]

        # Filter out empty lines and comment-only lines (<!-- ... -->)
        $contentLines = $sectionContent -split '\r?\n' |
            Where-Object { $_.Trim() -ne '' } |
            Where-Object { $_ -notmatch '^\s*<!--.*-->\s*$' }

        if (-not $contentLines -or $contentLines.Count -lt 1) {
            $emptySections += $section
            $status = 'FAIL'
            $details += "Section '$section' has no content (only comments or blank lines)"
        }
    }
}

if ($missingSections.Count -gt 0) {
    $details += "Missing sections: $($missingSections -join ', ')"
}

# =============================================================================
# OUTPUT
# =============================================================================

if ($Json) {
    $result = [ordered]@{
        status                 = $status
        sections_found         = $sectionsFound
        sections_required      = $requiredSections.Count
        placeholders_remaining = $placeholdersRemaining
        missing_sections       = @($missingSections)
        empty_sections         = @($emptySections)
        details                = @($details)
    }
    Write-Output ($result | ConvertTo-Json -Compress)
} else {
    if ($status -eq 'PASS') {
        Write-Output "PASS: PREMISE.md is valid ($sectionsFound/$($requiredSections.Count) sections, 0 placeholders)"
    } else {
        Write-Error "FAIL: PREMISE.md validation failed"
        foreach ($detail in $details) {
            Write-Host "  - $detail"
        }
    }
}

# Exit with appropriate code
if ($status -eq 'PASS') {
    exit 0
} else {
    exit 1
}
