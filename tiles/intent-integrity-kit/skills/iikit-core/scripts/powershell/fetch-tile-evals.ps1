#!/usr/bin/env pwsh
# Fetch Tessl eval results for a tile and save them for dashboard consumption

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Run,
    [switch]$Help,
    [Parameter(Position = 0)]
    [string]$TileName
)

$ErrorActionPreference = 'Stop'

# Show help if requested
if ($Help) {
    Write-Output "Usage: ./fetch-tile-evals.ps1 [-Json] [-Run] [-Help] <TileName>"
    Write-Output "  TileName   Full tile name (e.g., tessl-labs/some-tile)"
    Write-Output "  -Json      Output summary as JSON"
    Write-Output "  -Run       Run eval if none found"
    Write-Output "  -Help      Show this help message"
    exit 0
}

# Load common functions
. "$PSScriptRoot/common.ps1"

if (-not $TileName) {
    Write-Error "tile-name argument is required. Run with -Help for usage."
    exit 1
}

# Check tessl CLI available — exit 0 silently if not
if (-not (Get-Command tessl -ErrorAction SilentlyContinue)) {
    if ($Json) {
        Write-Output '{"status":"skipped","reason":"tessl CLI not available"}'
    }
    exit 0
}

# Split tile name into workspace and tile
$parts = $TileName -split '/', 2
if ($parts.Count -ne 2) {
    Write-Error "tile-name must be in workspace/tile format (e.g., tessl-labs/some-tile)"
    exit 1
}
$Workspace = $parts[0]
$Tile = $parts[1]

$repoRoot = Get-RepoRoot
$evalsDir = Join-Path $repoRoot '.specify' 'evals'
New-Item -ItemType Directory -Path $evalsDir -Force | Out-Null

$evalFile = Join-Path $evalsDir "$Workspace--$Tile.json"

# Try to find latest completed eval
try {
    $evalListRaw = tessl eval list --json --limit 1 --workspace $Workspace --tile $Tile 2>$null
    $evalList = $evalListRaw | ConvertFrom-Json
} catch {
    $evalList = @()
}

# If no evals and -Run requested, trigger one
if (-not $evalList -or $evalList.Count -eq 0) {
    if ($Run) {
        Write-Output "[specify] No evals found for $TileName, running eval..." | Write-Host
        try { tessl eval run --workspace $Workspace --tile $Tile 2>$null } catch {}
        try {
            $evalListRaw = tessl eval list --json --limit 1 --workspace $Workspace --tile $Tile 2>$null
            $evalList = $evalListRaw | ConvertFrom-Json
        } catch {
            $evalList = @()
        }
    }
}

# If still no evals, report and exit
if (-not $evalList -or $evalList.Count -eq 0) {
    if ($Json) {
        Write-Output "{`"tile`":`"$TileName`",`"status`":`"no_evals`"}"
    } else {
        Write-Warning "[specify] No eval results found for $TileName"
    }
    exit 0
}

# Extract eval ID from list (first result)
$evalId = $evalList[0].id
if (-not $evalId) {
    if ($Json) {
        Write-Output "{`"tile`":`"$TileName`",`"status`":`"no_evals`"}"
    } else {
        Write-Warning "[specify] Could not extract eval ID for $TileName"
    }
    exit 0
}

# Fetch full eval results
try {
    $evalDataRaw = tessl eval view --json $evalId 2>$null
    $evalData = $evalDataRaw | ConvertFrom-Json
} catch {
    if ($Json) {
        Write-Output "{`"tile`":`"$TileName`",`"status`":`"fetch_failed`"}"
    } else {
        Write-Warning "[specify] Failed to fetch eval details for $TileName (eval $evalId)"
    }
    exit 0
}

# Save full results
$evalDataRaw | Set-Content -Path $evalFile -Encoding UTF8

# Extract summary fields
$score = if ($evalData.score) { $evalData.score } elseif ($evalData.total_score) { $evalData.total_score } else { 0 }
$maxScore = if ($evalData.max_score) { $evalData.max_score } else { 100 }
$scenarios = if ($evalData.scenarios) { $evalData.scenarios.Count } else { 0 }
$scoredAt = if ($evalData.scored_at) { $evalData.scored_at } elseif ($evalData.completed_at) { $evalData.completed_at } elseif ($evalData.created_at) { $evalData.created_at } else { "unknown" }

# Calculate percentage
$pct = if ($maxScore -gt 0) { [math]::Floor(($score * 100) / $maxScore) } else { 0 }

if ($Json) {
    $result = [PSCustomObject]@{
        tile      = $TileName
        score     = $score
        max_score = $maxScore
        pct       = $pct
        scenarios = $scenarios
        scored_at = $scoredAt
        eval_file = $evalFile
    }
    $result | ConvertTo-Json -Compress
} else {
    Write-Output "[specify] Eval for ${TileName}: $score/$maxScore ($pct%) - $scenarios scenarios, scored $scoredAt"
    Write-Output "[specify] Full results saved to $evalFile"
}
