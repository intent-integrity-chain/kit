#!/usr/bin/env pwsh
# Set the active feature for the current project

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Selector,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output @"
Usage: set-active-feature.ps1 [-Json] <selector>

Set the active feature for the current project.

SELECTOR:
  Number:       1, 001, 3
  Partial name: user-auth, bugfix
  Full dir:     001-user-auth

OPTIONS:
  -Json      Output in JSON format
  -Help      Show this help message

EXAMPLES:
  .\set-active-feature.ps1 1
  .\set-active-feature.ps1 user-auth
  .\set-active-feature.ps1 -Json 001-user-auth

"@
    exit 0
}

if (-not $Selector) {
    Write-Error "No feature selector provided. Use -Help for usage."
    exit 1
}

# Source common functions
. "$PSScriptRoot/common.ps1"

$repoRoot = Get-RepoRoot
$specsDir = Join-Path $repoRoot 'specs'

if (-not (Test-Path $specsDir -PathType Container)) {
    Write-Error "No specs/ directory found. Run /iikit-01-specify first."
    exit 1
}

# Collect all feature directories
$features = @(Get-ChildItem -Path $specsDir -Directory | Where-Object { $_.Name -match '^[0-9]{3}-' })

if ($features.Count -eq 0) {
    Write-Error "No feature directories found in specs/."
    exit 1
}

$matches = @()

# Try matching as a number (e.g., 1 -> 001, 001 -> 001)
if ($Selector -match '^\d+$') {
    $prefix = '{0:000}' -f [int]$Selector
    $matches = @($features | Where-Object { $_.Name -match "^$prefix-" })
}

# If no match by number, try exact directory name
if ($matches.Count -eq 0) {
    $matches = @($features | Where-Object { $_.Name -eq $Selector })
}

# If still no match, try partial name match
if ($matches.Count -eq 0) {
    $matches = @($features | Where-Object { $_.Name -like "*$Selector*" })
}

# Handle results
if ($matches.Count -eq 0) {
    Write-Error "No feature matching '$Selector' found."
    Write-Host "Available features:"
    foreach ($f in $features) {
        Write-Host "  - $($f.Name)"
    }
    exit 1
} elseif ($matches.Count -gt 1) {
    Write-Error "Ambiguous selector '$Selector' matches multiple features:"
    foreach ($f in $matches) {
        Write-Host "  - $($f.Name)"
    }
    Write-Host "Be more specific."
    exit 1
}

# Exactly one match
$feature = $matches[0].Name
Write-ActiveFeature -Feature $feature
$env:SPECIFY_FEATURE = $feature

$stage = Get-FeatureStage -RepoRoot $repoRoot -Feature $feature

if ($Json) {
    [PSCustomObject]@{
        active_feature = $feature
        stage = $stage
    } | ConvertTo-Json -Compress
} else {
    Write-Output "Active feature set to: $feature"
    Write-Output "Stage: $stage"
}
