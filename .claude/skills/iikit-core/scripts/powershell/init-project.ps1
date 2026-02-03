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

if ($Json) {
    $result = @{
        success = $true
        git_initialized = $gitInitialized
        git_status = $gitStatus
        constitution_committed = $constitutionCommitted
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
}
