#!/usr/bin/env pwsh
# Bugfix helper functions for the iikit-bugfix skill
# Provides: --list-features, --next-bug-id, --next-task-ids, --validate-feature
# Cross-platform parity with bugfix-helpers.sh (Constitution III)

param(
    [Parameter(Position = 0)]
    [string]$Subcommand,

    [Parameter(Position = 1)]
    [string]$Arg1,

    [Parameter(Position = 2)]
    [string]$Arg2
)

$ErrorActionPreference = 'Stop'

# Source common functions
. (Join-Path $PSScriptRoot 'common.ps1')

# =============================================================================
# SUBCOMMANDS
# =============================================================================

function Invoke-ListFeatures {
    $result = Get-FeaturesJson
    if (-not $result) { Write-Output '[]' } else { Write-Output $result }
}

function Invoke-NextBugId {
    param([string]$FeatureDir)

    $bugsFile = Join-Path $FeatureDir 'bugs.md'

    if (-not (Test-Path $bugsFile)) {
        Write-Output 'BUG-001'
        return
    }

    $maxId = 0
    $content = Get-Content -Path $bugsFile -ErrorAction SilentlyContinue

    foreach ($line in $content) {
        if ($line -match '^##\s+BUG-(\d+)') {
            $num = [int]$Matches[1]
            if ($num -gt $maxId) {
                $maxId = $num
            }
        }
    }

    $next = $maxId + 1
    Write-Output ('BUG-{0:D3}' -f $next)
}

function Invoke-NextTaskIds {
    param(
        [string]$FeatureDir,
        [int]$Count = 3
    )

    $tasksFile = Join-Path $FeatureDir 'tasks.md'
    $maxId = 0

    if (Test-Path $tasksFile) {
        $content = Get-Content -Path $tasksFile -ErrorAction SilentlyContinue

        foreach ($line in $content) {
            if ($line -match 'T-B(\d+)') {
                $num = [int]$Matches[1]
                if ($num -gt $maxId) {
                    $maxId = $num
                }
            }
        }
    }

    $start = $maxId + 1
    $ids = @()
    for ($i = 0; $i -lt $Count; $i++) {
        $id = $start + $i
        $ids += '"T-B{0:D3}"' -f $id
    }

    $startStr = 'T-B{0:D3}' -f $start
    $idsStr = $ids -join ','
    $json = '{{"start":"{0}","ids":[{1}]}}' -f $startStr, $idsStr
    Write-Output $json
}

function Invoke-ValidateFeature {
    param([string]$FeatureDir)

    if (-not (Test-Path $FeatureDir -PathType Container)) {
        $json = '{{"valid":false,"error":"Feature directory not found: {0}"}}' -f $FeatureDir
        Write-Output $json
        exit 1
    }

    $specFile = Join-Path $FeatureDir 'spec.md'
    if (-not (Test-Path $specFile)) {
        $json = '{{"valid":false,"error":"spec.md not found in {0}. Run /iikit-01-specify first."}}' -f $FeatureDir
        Write-Output $json
        exit 1
    }

    $hasTasks = (Test-Path (Join-Path $FeatureDir 'tasks.md')).ToString().ToLower()
    $hasBugs = (Test-Path (Join-Path $FeatureDir 'bugs.md')).ToString().ToLower()
    $hasTests = (Test-Path (Join-Path $FeatureDir 'tests/test-specs.md')).ToString().ToLower()

    $json = '{{"valid":true,"has_tasks":{0},"has_bugs":{1},"has_tests":{2}}}' -f $hasTasks, $hasBugs, $hasTests
    Write-Output $json
}

# =============================================================================
# MAIN DISPATCHER
# =============================================================================

if (-not $Subcommand) {
    Write-Error 'Usage: bugfix-helpers.ps1 <subcommand> [args...]'
    Write-Error 'Subcommands: --list-features, --next-bug-id, --next-task-ids, --validate-feature'
    exit 1
}

switch ($Subcommand) {
    '--list-features' {
        Invoke-ListFeatures
    }
    '--next-bug-id' {
        if (-not $Arg1) {
            Write-Error 'Usage: bugfix-helpers.ps1 --next-bug-id <feature_dir>'
            exit 1
        }
        Invoke-NextBugId -FeatureDir $Arg1
    }
    '--next-task-ids' {
        if (-not $Arg1) {
            Write-Error 'Usage: bugfix-helpers.ps1 --next-task-ids <feature_dir> [count]'
            exit 1
        }
        $count = if ($Arg2) { [int]$Arg2 } else { 3 }
        Invoke-NextTaskIds -FeatureDir $Arg1 -Count $count
    }
    '--validate-feature' {
        if (-not $Arg1) {
            Write-Error 'Usage: bugfix-helpers.ps1 --validate-feature <feature_dir>'
            exit 1
        }
        Invoke-ValidateFeature -FeatureDir $Arg1
    }
    default {
        Write-Error "Unknown subcommand: $Subcommand"
        Write-Error 'Available: --list-features, --next-bug-id, --next-task-ids, --validate-feature'
        exit 1
    }
}
