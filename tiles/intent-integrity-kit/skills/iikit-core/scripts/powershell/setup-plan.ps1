#!/usr/bin/env pwsh
# Setup implementation plan for a feature

[CmdletBinding()]
param(
    [switch]$Json,
    [string]$ProjectRoot,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# Show help if requested
if ($Help) {
    Write-Output "Usage: ./setup-plan.ps1 [-Json] [-ProjectRoot PATH] [-Help]"
    Write-Output "  -Json          Output results in JSON format"
    Write-Output "  -ProjectRoot   Override project root directory (for testing)"
    Write-Output "  -Help          Show this help message"
    exit 0
}

# Load common functions
. "$PSScriptRoot/common.ps1"

# Check if we're on a proper feature branch FIRST (may set SPECIFY_FEATURE)
# This must happen before Get-FeaturePathsEnv so it uses the corrected feature name
if ($ProjectRoot) {
    $repoRoot = $ProjectRoot
} else {
    $repoRoot = Get-RepoRoot
}
$hasGit = Test-HasGit
$currentBranch = Get-CurrentBranch
if (-not (Test-FeatureBranch -Branch $currentBranch -HasGit $hasGit)) {
    exit 1
}

# Now get all paths (will use SPECIFY_FEATURE if it was set by Test-FeatureBranch)
$paths = Get-FeaturePathsEnv

# Override paths if -ProjectRoot was specified
if ($ProjectRoot) {
    $paths.REPO_ROOT = $ProjectRoot
    $paths.FEATURE_DIR = Find-FeatureDirByPrefix -RepoRoot $ProjectRoot -BranchName $currentBranch
    $paths.FEATURE_SPEC = Join-Path $paths.FEATURE_DIR 'spec.md'
    $paths.IMPL_PLAN = Join-Path $paths.FEATURE_DIR 'plan.md'
    $paths.TASKS = Join-Path $paths.FEATURE_DIR 'tasks.md'
}

# VALIDATION: Check constitution exists
if (-not (Test-Constitution -RepoRoot $paths.REPO_ROOT)) {
    exit 1
}

# VALIDATION: Check spec.md exists and has required structure
if (-not (Test-Spec -SpecFile $paths.FEATURE_SPEC)) {
    exit 1
}

# Report spec quality score
$specQuality = Get-SpecQualityScore -SpecFile $paths.FEATURE_SPEC
Write-Output "Spec quality score: $specQuality/10"
if ($specQuality -lt 6) {
    Write-Warning "Spec quality is low. Consider running /iikit-02-clarify."
}

# Ensure the feature directory exists
New-Item -ItemType Directory -Path $paths.FEATURE_DIR -Force | Out-Null

# Copy plan template if it exists, otherwise note it or create empty file
# Template path relative to script location (works for both .tessl and .claude installs)
$template = Join-Path $PSScriptRoot '..\..\templates\plan-template.md'
if (Test-Path $template) {
    Copy-Item $template $paths.IMPL_PLAN -Force
    Write-Output "Copied plan template to $($paths.IMPL_PLAN)"
} else {
    Write-Warning "Plan template not found at $template"
    # Create a basic plan file if template doesn't exist
    New-Item -ItemType File -Path $paths.IMPL_PLAN -Force | Out-Null
}

# Output results
if ($Json) {
    $result = [PSCustomObject]@{
        FEATURE_SPEC = $paths.FEATURE_SPEC
        IMPL_PLAN = $paths.IMPL_PLAN
        FEATURE_DIR = $paths.FEATURE_DIR
        BRANCH = $paths.CURRENT_BRANCH
        HAS_GIT = $paths.HAS_GIT
    }
    $result | ConvertTo-Json -Compress
} else {
    Write-Output "FEATURE_SPEC: $($paths.FEATURE_SPEC)"
    Write-Output "IMPL_PLAN: $($paths.IMPL_PLAN)"
    Write-Output "FEATURE_DIR: $($paths.FEATURE_DIR)"
    Write-Output "BRANCH: $($paths.CURRENT_BRANCH)"
    Write-Output "HAS_GIT: $($paths.HAS_GIT)"
}
