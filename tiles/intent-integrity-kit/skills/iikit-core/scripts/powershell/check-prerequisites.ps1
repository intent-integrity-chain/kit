#!/usr/bin/env pwsh

# Phase-aware prerequisite checking script (PowerShell)
#
# Usage: ./check-prerequisites.ps1 -Phase <PHASE> [-Json] [-ProjectRoot PATH]
#
# PHASES: 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, bugfix, core
#
# LEGACY FLAGS (deprecated, map to phases):
#   -PathsOnly    -> -Phase core
#   -RequireTasks -> -Phase 08
#   -IncludeTasks (used with -RequireTasks)

[CmdletBinding()]
param(
    [string]$Phase,
    [switch]$Json,
    [string]$ProjectRoot,
    [switch]$RequireTasks,
    [switch]$IncludeTasks,
    [switch]$PathsOnly,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# Show help if requested
if ($Help) {
    Write-Output @"
Usage: check-prerequisites.ps1 -Phase <PHASE> [-Json] [-ProjectRoot PATH]

Phase-aware prerequisite checking for IIKit workflow.

PHASES:
  00       Constitution (no validation)
  01       Specify (soft constitution)
  02       Clarify (soft constitution, requires spec)
  bugfix   Bug fix (soft constitution)
  03       Plan (hard constitution, requires spec, copies template)
  04       Checklist (basic constitution, requires spec + plan)
  05       Testify (basic constitution, requires spec + plan, soft checklist)
  06       Tasks (basic constitution, requires spec + plan, soft checklist)
  07       Analyze (hard constitution, requires spec + plan + tasks, soft checklist)
  08       Implement (hard constitution, requires spec + plan + tasks, hard checklist)
  09       Tasks to Issues (implicit constitution, requires spec + plan + tasks)
  core     Paths only (no validation)

OPTIONS:
  -Json          Output in JSON format
  -ProjectRoot   Override project root directory (for testing)
  -Help          Show this help message

LEGACY FLAGS (deprecated):
  -PathsOnly     Use -Phase core instead
  -RequireTasks  Use -Phase 08 instead
  -IncludeTasks  Use -Phase 08 instead

"@
    exit 0
}

# Map legacy flags to phase (with deprecation warning)
if (-not $Phase) {
    if ($PathsOnly) {
        Write-Warning "DEPRECATED: -PathsOnly is deprecated, use -Phase core"
        $Phase = 'core'
    } elseif ($RequireTasks) {
        Write-Warning "DEPRECATED: -RequireTasks/-IncludeTasks are deprecated, use -Phase 08"
        $Phase = '08'
    } else {
        $Phase = '04'
    }
}

# Source common functions
. "$PSScriptRoot/common.ps1"

# =============================================================================
# PHASE CONFIGURATION
# =============================================================================

$phaseConfig = @{
    '00'     = @{ Const='none';     Spec='no';       Plan='no';       Tasks='no';       IncTasks='no';  Checklist='none'; Extras='' }
    '01'     = @{ Const='soft';     Spec='no';       Plan='no';       Tasks='no';       IncTasks='no';  Checklist='none'; Extras='' }
    '02'     = @{ Const='soft';     Spec='required'; Plan='no';       Tasks='no';       IncTasks='no';  Checklist='none'; Extras='' }
    'bugfix' = @{ Const='soft';     Spec='no';       Plan='no';       Tasks='no';       IncTasks='no';  Checklist='none'; Extras='' }
    '03'     = @{ Const='hard';     Spec='required'; Plan='no';       Tasks='no';       IncTasks='no';  Checklist='none'; Extras='spec_quality,copy_plan_template' }
    '04'     = @{ Const='basic';    Spec='required'; Plan='required'; Tasks='no';       IncTasks='no';  Checklist='none'; Extras='' }
    '05'     = @{ Const='basic';    Spec='required'; Plan='required'; Tasks='no';       IncTasks='no';  Checklist='soft'; Extras='' }
    '06'     = @{ Const='basic';    Spec='required'; Plan='required'; Tasks='no';       IncTasks='no';  Checklist='soft'; Extras='' }
    '07'     = @{ Const='hard';     Spec='required'; Plan='required'; Tasks='required'; IncTasks='yes'; Checklist='soft'; Extras='' }
    '08'     = @{ Const='hard';     Spec='required'; Plan='required'; Tasks='required'; IncTasks='yes'; Checklist='hard'; Extras='' }
    '09'     = @{ Const='implicit'; Spec='required'; Plan='required'; Tasks='required'; IncTasks='yes'; Checklist='none'; Extras='' }
    'core'   = @{ Const='none';     Spec='no';       Plan='no';       Tasks='no';       IncTasks='no';  Checklist='none'; Extras='paths_only' }
}

if (-not $phaseConfig.ContainsKey($Phase)) {
    Write-Error "Unknown phase '$Phase'. Valid: 00 01 02 03 04 05 06 07 08 09 bugfix core"
    exit 1
}

$cfg = $phaseConfig[$Phase]

# Legacy -IncludeTasks override
if ($IncludeTasks -and $cfg.IncTasks -eq 'no') {
    $cfg.IncTasks = 'yes'
}

# =============================================================================
# FEATURE DETECTION
# =============================================================================

if ($ProjectRoot) {
    $repoRoot = $ProjectRoot
} else {
    $repoRoot = Get-RepoRoot
}
$hasGit = Test-HasGit
$currentBranch = Get-CurrentBranch
$branchResult = Test-FeatureBranch -Branch $currentBranch -HasGit $hasGit
if ($branchResult -eq "NEEDS_SELECTION") {
    $featuresJson = Get-FeaturesJson
    if ($Json) {
        Write-Output "{`"needs_selection`":true,`"features`":$featuresJson}"
    } else {
        Write-Output "NEEDS_SELECTION: true"
        Write-Output "Run: /iikit-core use <feature> to select a feature."
    }
    exit 2
} elseif ($branchResult -eq "ERROR") {
    exit 1
}

# Get all feature paths
$paths = Get-FeaturePathsEnv

# Override paths if -ProjectRoot was specified
if ($ProjectRoot) {
    $paths.REPO_ROOT = $ProjectRoot
    $paths.FEATURE_DIR = Find-FeatureDirByPrefix -RepoRoot $ProjectRoot -BranchName $currentBranch
    $paths.FEATURE_SPEC = Join-Path $paths.FEATURE_DIR 'spec.md'
    $paths.IMPL_PLAN = Join-Path $paths.FEATURE_DIR 'plan.md'
    $paths.TASKS = Join-Path $paths.FEATURE_DIR 'tasks.md'
    $paths.RESEARCH = Join-Path $paths.FEATURE_DIR 'research.md'
    $paths.DATA_MODEL = Join-Path $paths.FEATURE_DIR 'data-model.md'
    $paths.QUICKSTART = Join-Path $paths.FEATURE_DIR 'quickstart.md'
    $paths.CONTRACTS_DIR = Join-Path $paths.FEATURE_DIR 'contracts'
}

# =============================================================================
# PATHS-ONLY SHORT CIRCUIT (core phase)
# =============================================================================

if ($cfg.Extras -match 'paths_only') {
    if ($Json) {
        $result = [ordered]@{
            phase             = $Phase
            constitution_mode = $cfg.Const
            REPO_ROOT         = $paths.REPO_ROOT
            BRANCH            = $paths.CURRENT_BRANCH
            HAS_GIT           = $hasGit
            FEATURE_DIR       = $paths.FEATURE_DIR
            FEATURE_SPEC      = $paths.FEATURE_SPEC
            IMPL_PLAN         = $paths.IMPL_PLAN
            TASKS             = $paths.TASKS
            AVAILABLE_DOCS    = @()
            validated         = [ordered]@{ constitution = $false; spec = $false; plan = $false; tasks = $false }
            warnings          = @()
        }
        ($result | ConvertTo-Json -Compress -Depth 3)
    } else {
        Write-Output "REPO_ROOT: $($paths.REPO_ROOT)"
        Write-Output "BRANCH: $($paths.CURRENT_BRANCH)"
        Write-Output "FEATURE_DIR: $($paths.FEATURE_DIR)"
        Write-Output "FEATURE_SPEC: $($paths.FEATURE_SPEC)"
        Write-Output "IMPL_PLAN: $($paths.IMPL_PLAN)"
        Write-Output "TASKS: $($paths.TASKS)"
    }
    # Launch dashboard
    & "$PSScriptRoot/ensure-dashboard.ps1"
    exit 0
}

# =============================================================================
# VALIDATION
# =============================================================================

$warnings = @()
$vConstitution = $false
$vSpec = $false
$vPlan = $false
$vTasks = $false

# Feature directory check
if (-not (Test-Path $paths.FEATURE_DIR -PathType Container)) {
    Write-Error "Feature directory not found: $($paths.FEATURE_DIR)"
    Write-Host "Run /iikit-01-specify first to create the feature structure."
    exit 1
}

# Constitution validation (per mode)
switch ($cfg.Const) {
    'none' {
        # Skip
    }
    'soft' {
        $constPath = Join-Path $repoRoot 'CONSTITUTION.md'
        if (Test-Path $constPath) {
            $vConstitution = $true
            $content = Get-Content -Path $constPath -Raw -ErrorAction SilentlyContinue
            if ($content -notmatch '## .*Principles|# .*Constitution') {
                $warnings += 'Constitution may be incomplete - missing principles section'
            }
        } else {
            $warnings += 'Constitution not found; recommended: /iikit-00-constitution'
        }
    }
    default {
        # basic, hard, implicit
        if (-not (Test-Constitution -RepoRoot $repoRoot)) {
            exit 1
        }
        $vConstitution = $true
    }
}

# Spec validation
if ($cfg.Spec -eq 'required') {
    if (-not (Test-Spec -SpecFile $paths.FEATURE_SPEC)) {
        exit 1
    }
    $vSpec = $true
}

# Phase 03 extras: spec quality
$specQuality = $null
if ($cfg.Extras -match 'spec_quality') {
    $specQuality = Get-SpecQualityScore -SpecFile $paths.FEATURE_SPEC
    Write-Host "Spec quality score: $specQuality/10" -ForegroundColor Cyan
    if ($specQuality -lt 6) {
        $warnings += "Spec quality is low ($specQuality/10). Consider running /iikit-02-clarify."
    }
}

# Plan validation
if ($cfg.Plan -eq 'required') {
    if (-not (Test-Plan -PlanFile $paths.IMPL_PLAN)) {
        exit 1
    }
    $vPlan = $true
}

# Phase 03 extras: copy plan template
$planTemplateCopied = $null
if ($cfg.Extras -match 'copy_plan_template') {
    New-Item -ItemType Directory -Path $paths.FEATURE_DIR -Force | Out-Null
    $template = Join-Path $PSScriptRoot '..\..\templates\plan-template.md'
    if (Test-Path $template) {
        Copy-Item $template $paths.IMPL_PLAN -Force
        Write-Host "Copied plan template to $($paths.IMPL_PLAN)" -ForegroundColor Cyan
        $planTemplateCopied = $true
    } else {
        $warnings += "Plan template not found at $template"
        New-Item -ItemType File -Path $paths.IMPL_PLAN -Force | Out-Null
        $planTemplateCopied = $false
    }
}

# Tasks validation
if ($cfg.Tasks -eq 'required') {
    if (-not (Test-Tasks -TasksFile $paths.TASKS)) {
        exit 1
    }
    $vTasks = $true
}

# Checklist gate
$checklistChecked = 0
$checklistTotal = 0
if ($cfg.Checklist -ne 'none') {
    $checklistsDir = Join-Path $paths.FEATURE_DIR 'checklists'
    if (Test-Path $checklistsDir) {
        Get-ChildItem -Path $checklistsDir -Filter '*.md' -ErrorAction SilentlyContinue | ForEach-Object {
            $content = Get-Content -Path $_.FullName -ErrorAction SilentlyContinue
            foreach ($line in $content) {
                if ($line -match '^- \[.\]') {
                    $checklistTotal++
                    if ($line -match '^- \[[xX]\]') {
                        $checklistChecked++
                    }
                }
            }
        }
    }

    if ($checklistTotal -gt 0 -and $checklistChecked -lt $checklistTotal) {
        $pct = [math]::Floor(($checklistChecked * 100) / $checklistTotal)
        if ($cfg.Checklist -eq 'hard') {
            $warnings += "Checklists incomplete ($checklistChecked/$checklistTotal items, ${pct}%). Must be 100% for implementation."
        } else {
            $warnings += "Checklists incomplete ($checklistChecked/$checklistTotal items, ${pct}%). Recommend /iikit-04-checklist."
        }
    }
}

# =============================================================================
# BUILD AVAILABLE DOCS
# =============================================================================

$docs = @()
if (Test-Path $paths.RESEARCH) { $docs += 'research.md' }
if (Test-Path $paths.DATA_MODEL) { $docs += 'data-model.md' }
if ((Test-Path $paths.CONTRACTS_DIR) -and (Get-ChildItem -Path $paths.CONTRACTS_DIR -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    $docs += 'contracts/'
}
if (Test-Path $paths.QUICKSTART) { $docs += 'quickstart.md' }
if ($cfg.IncTasks -eq 'yes' -and (Test-Path $paths.TASKS)) {
    $docs += 'tasks.md'
}

# =============================================================================
# OUTPUT
# =============================================================================

if ($Json) {
    $result = [ordered]@{
        phase             = $Phase
        constitution_mode = $cfg.Const
        FEATURE_DIR       = $paths.FEATURE_DIR
        FEATURE_SPEC      = $paths.FEATURE_SPEC
        IMPL_PLAN         = $paths.IMPL_PLAN
        TASKS             = $paths.TASKS
        BRANCH            = $paths.CURRENT_BRANCH
        HAS_GIT           = $hasGit
        REPO_ROOT         = $paths.REPO_ROOT
        AVAILABLE_DOCS    = $docs
        validated         = [ordered]@{
            constitution  = $vConstitution
            spec          = $vSpec
            plan          = $vPlan
            tasks         = $vTasks
        }
        warnings          = $warnings
    }

    # Phase 03 extras
    if ($null -ne $specQuality) {
        $result['spec_quality'] = $specQuality
    }
    if ($null -ne $planTemplateCopied) {
        $result['plan_template_copied'] = $planTemplateCopied
    }

    # Checklist info
    if ($cfg.Checklist -ne 'none' -and $checklistTotal -gt 0) {
        $result['checklist_checked'] = $checklistChecked
        $result['checklist_total'] = $checklistTotal
    }

    ($result | ConvertTo-Json -Compress -Depth 3)
} else {
    Write-Output "Phase: $Phase"
    Write-Output "FEATURE_DIR:$($paths.FEATURE_DIR)"
    Write-Output "AVAILABLE_DOCS:"

    Test-FileExists -Path $paths.RESEARCH -Description 'research.md' | Out-Null
    Test-FileExists -Path $paths.DATA_MODEL -Description 'data-model.md' | Out-Null
    Test-DirHasFiles -Path $paths.CONTRACTS_DIR -Description 'contracts/' | Out-Null
    Test-FileExists -Path $paths.QUICKSTART -Description 'quickstart.md' | Out-Null

    if ($cfg.IncTasks -eq 'yes') {
        Test-FileExists -Path $paths.TASKS -Description 'tasks.md' | Out-Null
    }

    if ($warnings.Count -gt 0) {
        Write-Output ""
        Write-Output "WARNINGS:"
        foreach ($w in $warnings) {
            Write-Output "  - $w"
        }
    }

    if ($null -ne $specQuality) {
        Write-Output "Spec quality score: $specQuality/10"
    }
}

# Launch dashboard (idempotent, never fails)
& "$PSScriptRoot/ensure-dashboard.ps1"
