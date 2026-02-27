#!/usr/bin/env pwsh
# next-step.ps1 — Single source of truth for IIKit next-step determination (PowerShell)
#
# Usage:
#   pwsh next-step.ps1 -Phase <completed_phase> -Json [-ProjectRoot PATH]
#
# -Phase values: 00, 01, 02, 03, 04, 05, 06, 07, 08, clarify, bugfix, core, status
# -Json: (required) output JSON
# -ProjectRoot: optional, defaults to git root
#
# Mandatory path: 00 -> 01 -> 02 -> [04 if TDD] -> 05 -> 07
# Optional steps: 03 (checklist), 06 (analyze), 08 (tasks-to-issues)

param(
    [Parameter(Mandatory = $true)]
    [string]$Phase,

    [switch]$Json,

    [string]$ProjectRoot
)

if (-not $Json) {
    Write-Error "-Json is required"
    exit 1
}

. (Join-Path $PSScriptRoot 'common.ps1')

# =============================================================================
# PROJECT DETECTION
# =============================================================================

if ($ProjectRoot) {
    $RepoRoot = $ProjectRoot
} else {
    $RepoRoot = Get-RepoRoot
    if (-not $RepoRoot) {
        Write-Output '{"error":"Cannot determine project root"}'
        exit 1
    }
}

# =============================================================================
# FEATURE DETECTION
# =============================================================================

$Feature = Read-ActiveFeature -RepoRoot $RepoRoot
$FeatureDir = if ($Feature) { Join-Path $RepoRoot 'specs' $Feature } else { $null }

# =============================================================================
# ARTIFACT EXISTENCE
# =============================================================================

$A_CONSTITUTION = Test-Path (Join-Path $RepoRoot 'CONSTITUTION.md')
$A_SPEC = $false
$A_PLAN = $false
$A_TASKS = $false
$A_CHECKLISTS = $false
$A_TEST_SPECS = $false
$A_ANALYSIS = $false

if ($FeatureDir -and (Test-Path $FeatureDir -PathType Container)) {
    $A_SPEC = Test-Path (Join-Path $FeatureDir 'spec.md')
    $A_PLAN = Test-Path (Join-Path $FeatureDir 'plan.md')
    $A_TASKS = Test-Path (Join-Path $FeatureDir 'tasks.md')

    $checklistsDir = Join-Path $FeatureDir 'checklists'
    if ((Test-Path $checklistsDir -PathType Container) -and (Get-ChildItem $checklistsDir -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        $A_CHECKLISTS = $true
    }

    if (Test-Path (Join-Path $FeatureDir 'tests' 'test-specs.md')) {
        $A_TEST_SPECS = $true
    }
    $featuresDir = Join-Path $FeatureDir 'tests' 'features'
    if ((Test-Path $featuresDir -PathType Container) -and (Get-ChildItem $featuresDir -Filter '*.feature' -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        $A_TEST_SPECS = $true
    }

    $A_ANALYSIS = Test-Path (Join-Path $FeatureDir 'analysis.md')
}

# =============================================================================
# TDD DETERMINATION
# =============================================================================

$TDD_MANDATORY = $false
$contextFile = Join-Path $RepoRoot '.specify' 'context.json'
$tddStatus = 'unknown'

if (Test-Path $contextFile) {
    try {
        $ctx = Get-Content $contextFile -Raw | ConvertFrom-Json
        if ($ctx.tdd_determination) {
            $tddStatus = $ctx.tdd_determination
        }
    } catch {}
}

if ($tddStatus -eq 'unknown') {
    $constitutionPath = Join-Path $RepoRoot 'CONSTITUTION.md'
    if (Test-Path $constitutionPath) {
        $content = Get-Content $constitutionPath -Raw -ErrorAction SilentlyContinue
        if ($content -match 'MUST.*(TDD|BDD|test-first|red-green-refactor|write tests before|behavior-driven|behaviour-driven)' -or
            $content -match '(TDD|BDD|test-first|red-green-refactor|write tests before|behavior-driven|behaviour-driven).*MUST' -or
            $content -match 'MUST.*(test-driven|tests.*before.*code|tests.*before.*implementation)') {
            $tddStatus = 'mandatory'
        } else {
            $tddStatus = 'optional'
        }
    }
}

if ($tddStatus -eq 'mandatory') { $TDD_MANDATORY = $true }

# =============================================================================
# FEATURE STAGE
# =============================================================================

$FeatureStage = 'unknown'
if ($Feature) {
    $FeatureStage = Get-FeatureStage -RepoRoot $RepoRoot -Feature $Feature
}

# =============================================================================
# CHECKLIST STATUS
# =============================================================================

$CHECKLIST_COMPLETE = $false
if ($A_CHECKLISTS -and $FeatureDir) {
    $clTotal = 0
    $clChecked = 0
    $checklistFiles = Get-ChildItem (Join-Path $FeatureDir 'checklists') -Filter '*.md' -ErrorAction SilentlyContinue
    foreach ($clFile in $checklistFiles) {
        foreach ($line in (Get-Content $clFile.FullName)) {
            if ($line -match '^\s*- \[.\]') {
                $clTotal++
                if ($line -match '^\s*- \[[xX]\]') {
                    $clChecked++
                }
            }
        }
    }
    if ($clTotal -gt 0 -and $clChecked -eq $clTotal) {
        $CHECKLIST_COMPLETE = $true
    }
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Get-ModelTier {
    param([string]$P)
    switch ($P) {
        { $_ -in 'core', '03', '08' }              { return 'light' }
        { $_ -in '01', 'clarify', '04', '05', 'bugfix' } { return 'medium' }
        { $_ -in '00', '02', '06', '07' }           { return 'heavy' }
        'status'                                     { return 'light' }
        ''                                           { return $null }
        default                                      { return 'medium' }
    }
}

function Get-ClearAfter {
    param([string]$Completed)
    switch ($Completed) {
        '02'      { return $true }
        '03'      { return $true }
        '07'      { return $true }
        'clarify' { return $true }
        default   { return $false }
    }
}

function Get-ClearBefore {
    param([string]$Next)
    switch ($Next) {
        '02' { return $true }
        '05' { return $true }
        '06' { return $true }
        '07' { return $true }
        default { return $false }
    }
}

# =============================================================================
# ARTIFACT-STATE FALLBACK
# =============================================================================

function Get-ArtifactStateFallback {
    if (-not $A_CONSTITUTION) {
        return @{ step = '/iikit-00-constitution'; phase = '00' }
    }
    if (-not $Feature -or -not $FeatureDir -or -not (Test-Path $FeatureDir -PathType Container) -or -not $A_SPEC) {
        return @{ step = '/iikit-01-specify'; phase = '01' }
    }
    if (-not $A_PLAN) {
        return @{ step = '/iikit-02-plan'; phase = '02' }
    }
    if ($TDD_MANDATORY -and -not $A_TEST_SPECS) {
        return @{ step = '/iikit-04-testify'; phase = '04' }
    }
    if (-not $A_TASKS) {
        return @{ step = '/iikit-05-tasks'; phase = '05' }
    }
    if ($FeatureStage -eq 'complete') {
        return @{ step = $null; phase = $null }
    }
    return @{ step = '/iikit-07-implement'; phase = '07' }
}

# =============================================================================
# PHASE-BASED STATE MACHINE
# =============================================================================

function Get-NextStep {
    param([string]$Completed)

    switch ($Completed) {
        '00' { return @{ step = '/iikit-01-specify'; phase = '01' } }
        '01' { return @{ step = '/iikit-02-plan'; phase = '02' } }
        '02' {
            if ($TDD_MANDATORY) {
                return @{ step = '/iikit-04-testify'; phase = '04' }
            }
            return @{ step = '/iikit-05-tasks'; phase = '05' }
        }
        '03' {
            if ($TDD_MANDATORY -and -not $A_TEST_SPECS) {
                return @{ step = '/iikit-04-testify'; phase = '04' }
            }
            return @{ step = '/iikit-05-tasks'; phase = '05' }
        }
        '04' { return @{ step = '/iikit-05-tasks'; phase = '05' } }
        '05' { return @{ step = '/iikit-07-implement'; phase = '07' } }
        '06' { return @{ step = '/iikit-07-implement'; phase = '07' } }
        '07' {
            if ($FeatureStage -eq 'complete') {
                return @{ step = $null; phase = $null }
            }
            return @{ step = '/iikit-07-implement'; phase = '07' }
        }
        '08' { return @{ step = $null; phase = $null } }
        'bugfix' { return @{ step = '/iikit-07-implement'; phase = '07' } }
        default { return Get-ArtifactStateFallback }
    }
}

# =============================================================================
# BUILD ALT STEPS
# =============================================================================

function Get-AltSteps {
    param([string]$Completed, [string]$NextPhase)

    $alts = @()

    # Clarify always available when artifacts exist
    if ($A_SPEC -or $A_PLAN -or $A_TASKS) {
        $alts += @{ step = '/iikit-clarify'; reason = 'Resolve ambiguities'; model_tier = 'medium' }
    }

    switch ($Completed) {
        '02' {
            $alts += @{ step = '/iikit-03-checklist'; reason = 'Optional quality checklist'; model_tier = 'light' }
            if (-not $TDD_MANDATORY) {
                $alts += @{ step = '/iikit-04-testify'; reason = 'Optional test specifications'; model_tier = 'medium' }
            }
        }
        '03' {
            if (-not $TDD_MANDATORY) {
                $alts += @{ step = '/iikit-04-testify'; reason = 'Optional test specifications'; model_tier = 'medium' }
            }
        }
        '05' {
            $alts += @{ step = '/iikit-06-analyze'; reason = 'Optional consistency analysis'; model_tier = 'heavy' }
        }
        '07' {
            if ($FeatureStage -eq 'complete') {
                $alts += @{ step = '/iikit-08-taskstoissues'; reason = 'Export tasks to GitHub Issues'; model_tier = 'light' }
            }
        }
    }

    return $alts
}

# =============================================================================
# MAIN
# =============================================================================

$result = Get-NextStep -Completed $Phase
$nextStep = $result.step
$nextPhase = $result.phase

$clearAfter = Get-ClearAfter -Completed $Phase
$clearBefore = if ($nextPhase) { Get-ClearBefore -Next $nextPhase } else { $false }
$modelTier = if ($nextPhase) { Get-ModelTier -P $nextPhase } else { $null }
$altSteps = Get-AltSteps -Completed $Phase -NextPhase $nextPhase

# Build output object
$output = [ordered]@{
    current_phase = $Phase
    next_step     = $nextStep
    next_phase    = $nextPhase
    clear_before  = $clearBefore
    clear_after   = $clearAfter
    model_tier    = $modelTier
    feature_stage = $FeatureStage
    tdd_mandatory = $TDD_MANDATORY
    alt_steps     = @($altSteps)
}

$output | ConvertTo-Json -Compress -Depth 3
