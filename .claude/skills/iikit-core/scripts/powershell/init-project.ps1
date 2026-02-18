#!/usr/bin/env pwsh
# Initialize a intent-integrity-kit project with git
[CmdletBinding()]
param(
    [Alias('j')]
    [switch]$Json,
    [Alias('c')]
    [switch]$CommitConstitution,
    [Alias('h')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "Usage: ./init-project.ps1 [-Json] [-CommitConstitution]"
    Write-Host ""
    Write-Host "Initialize a intent-integrity-kit project with git repository."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Json                  Output in JSON format"
    Write-Host "  -CommitConstitution    Commit the constitution file after git init"
    Write-Host "  -Help                  Show this help message"
    exit 0
}

# Use current working directory as project root
$projectRoot = Get-Location

# Check if .specify exists (validates this is a intent-integrity-kit project)
if (-not (Test-Path (Join-Path $projectRoot '.specify'))) {
    if ($Json) {
        $result = @{
            success = $false
            error = "Not a intent-integrity-kit project: .specify directory not found"
            git_initialized = $false
        }
        $result | ConvertTo-Json -Compress
    } else {
        Write-Error "Not a intent-integrity-kit project. Directory .specify not found."
    }
    exit 1
}

# Check if already a git repo
$gitDir = Join-Path $projectRoot '.git'
if (Test-Path $gitDir) {
    $gitInitialized = $false
    $gitStatus = "already_initialized"
} else {
    # Initialize git
    git init $projectRoot 2>&1 | Out-Null
    $gitInitialized = $true
    $gitStatus = "initialized"
}

# Install git hooks for assertion integrity enforcement
# Helper function: install a single hook
function Install-IIKitHook {
    param(
        [string]$HookType,      # e.g., "pre-commit" or "post-commit"
        [string]$SourceFile,    # e.g., "pre-commit-hook.sh"
        [string]$Marker         # e.g., "IIKIT-PRE-COMMIT"
    )

    $result = @{ installed = $false; status = "skipped" }

    $gitDirPath = Join-Path $projectRoot '.git'
    if (-not (Test-Path $gitDirPath)) { return $result }

    $bashScriptDir = Join-Path (Split-Path $PSScriptRoot -Parent) "bash"
    $hookSource = Join-Path $bashScriptDir $SourceFile

    if (-not (Test-Path $hookSource)) {
        $result.status = "source_not_found"
        return $result
    }

    $hooksDir = Join-Path $gitDirPath "hooks"
    if (-not (Test-Path $hooksDir)) {
        New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
    }
    $existingHook = Join-Path $hooksDir $HookType

    if (-not (Test-Path $existingHook)) {
        Copy-Item $hookSource $existingHook
        $result.installed = $true
        $result.status = "installed"
    } elseif ((Get-Content $existingHook -Raw -ErrorAction SilentlyContinue) -match $Marker) {
        Copy-Item $hookSource $existingHook -Force
        $result.installed = $true
        $result.status = "updated"
    } else {
        $iikitHook = Join-Path $hooksDir "iikit-$HookType"
        Copy-Item $hookSource $iikitHook

        $hookContent = Get-Content $existingHook -Raw -ErrorAction SilentlyContinue
        if ($hookContent -notmatch "iikit-$HookType") {
            Add-Content -Path $existingHook -Value "`n# IIKit assertion integrity check"
            Add-Content -Path $existingHook -Value '"$(dirname "$0")/iikit-' -NoNewline
            Add-Content -Path $existingHook -Value "$HookType`""
        }
        $result.installed = $true
        $result.status = "installed_alongside"
    }

    return $result
}

# Install pre-commit hook (validates assertion hashes before commit)
$preHookResult = Install-IIKitHook -HookType "pre-commit" -SourceFile "pre-commit-hook.sh" -Marker "IIKIT-PRE-COMMIT"
$hookInstalled = $preHookResult.installed
$hookStatus = $preHookResult.status

# Install post-commit hook (stores assertion hashes as git notes after commit)
$postHookResult = Install-IIKitHook -HookType "post-commit" -SourceFile "post-commit-hook.sh" -Marker "IIKIT-POST-COMMIT"
$postHookInstalled = $postHookResult.installed
$postHookStatus = $postHookResult.status

# Commit constitution if requested and it exists
$constitutionCommitted = $false
$constitutionPath = Join-Path $projectRoot 'CONSTITUTION.md'
if ($CommitConstitution -and (Test-Path $constitutionPath)) {
    Set-Location $projectRoot
    git add $constitutionPath

    # Also add README if it exists
    $readmePath = Join-Path $projectRoot 'README.md'
    if (Test-Path $readmePath) {
        git add $readmePath
    }

    # Check if there's anything to commit
    $stagedChanges = git diff --cached --name-only 2>$null
    if ($stagedChanges) {
        git commit -m "Initialize intent-integrity-kit project with constitution" 2>&1 | Out-Null
        $constitutionCommitted = $true
    }
}

function Report-HookStatus {
    param([string]$HookName, [string]$Status)
    switch ($Status) {
        "installed"           { Write-Output "[specify] $HookName hook installed" }
        "updated"             { Write-Output "[specify] $HookName hook updated" }
        "installed_alongside" { Write-Output "[specify] $HookName hook installed alongside existing hook" }
        "source_not_found"    { Write-Warning "[specify] $HookName hook source not found - skipped installation" }
    }
}

if ($Json) {
    $result = @{
        success = $true
        git_initialized = $gitInitialized
        git_status = $gitStatus
        constitution_committed = $constitutionCommitted
        hook_installed = $hookInstalled
        hook_status = $hookStatus
        post_hook_installed = $postHookInstalled
        post_hook_status = $postHookStatus
        project_root = $projectRoot.ToString()
    }
    $result | ConvertTo-Json -Compress
} else {
    if ($gitInitialized) {
        Write-Output "[specify] Git repository initialized at $projectRoot"
    } else {
        Write-Output "[specify] Git repository already exists at $projectRoot"
    }
    if ($constitutionCommitted) {
        Write-Output "[specify] Constitution committed to git"
    }
    Report-HookStatus "Pre-commit" $hookStatus
    Report-HookStatus "Post-commit" $postHookStatus
}
