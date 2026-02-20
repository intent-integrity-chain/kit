#!/usr/bin/env pwsh
# Detect git/GitHub environment for IIKit project initialization
# Pure probe — no mutations. Returns environment state as JSON or plain text.
[CmdletBinding()]
param(
    [Alias('j')]
    [switch]$Json,
    [Alias('h')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "Usage: ./git-setup.ps1 [-Json]"
    Write-Host ""
    Write-Host "Detect git and GitHub environment for IIKit project initialization."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Json        Output in JSON format"
    Write-Host "  -Help        Show this help message"
    Write-Host ""
    Write-Host "Output fields:"
    Write-Host "  git_available      Whether git is installed"
    Write-Host "  is_git_repo        Whether cwd is inside a git repository"
    Write-Host "  has_remote         Whether a remote (origin) is configured"
    Write-Host "  remote_url         The origin remote URL (empty if none)"
    Write-Host "  is_github_remote   Whether the remote URL points to GitHub"
    Write-Host "  gh_available       Whether the gh CLI is installed"
    Write-Host "  gh_authenticated   Whether gh is authenticated"
    Write-Host "  has_iikit_artifacts Whether .specify or CONSTITUTION.md exists"
    exit 0
}

# --- Probe git ---
$gitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)

$isGitRepo = $false
if ($gitAvailable) {
    try {
        $null = git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -eq 0) { $isGitRepo = $true }
    } catch { }
}

# --- Probe remote ---
$hasRemote = $false
$remoteUrl = ""
$isGithubRemote = $false

if ($isGitRepo) {
    try {
        $remoteUrl = git remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0 -and $remoteUrl) {
            $hasRemote = $true
            if ($remoteUrl -match 'github\.com') {
                $isGithubRemote = $true
            }
        } else {
            $remoteUrl = ""
        }
    } catch {
        $remoteUrl = ""
    }
}

# --- Probe gh CLI ---
$ghAvailable = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)

$ghAuthenticated = $false
if ($ghAvailable) {
    try {
        $null = gh auth status 2>$null
        if ($LASTEXITCODE -eq 0) { $ghAuthenticated = $true }
    } catch { }
}

# --- Probe IIKit artifacts ---
$hasIikitArtifacts = (Test-Path '.specify') -or (Test-Path 'CONSTITUTION.md') -or (Test-Path 'PREMISE.md')

# --- Output ---
if ($Json) {
    $result = @{
        git_available      = $gitAvailable
        is_git_repo        = $isGitRepo
        has_remote         = $hasRemote
        remote_url         = $remoteUrl
        is_github_remote   = $isGithubRemote
        gh_available       = $ghAvailable
        gh_authenticated   = $ghAuthenticated
        has_iikit_artifacts = $hasIikitArtifacts
    }
    $result | ConvertTo-Json -Compress
} else {
    Write-Host "Git available:       $gitAvailable"
    Write-Host "Is git repo:         $isGitRepo"
    Write-Host "Has remote:          $hasRemote"
    Write-Host "Remote URL:          $(if ($remoteUrl) { $remoteUrl } else { '(none)' })"
    Write-Host "Is GitHub remote:    $isGithubRemote"
    Write-Host "gh CLI available:    $ghAvailable"
    Write-Host "gh authenticated:    $ghAuthenticated"
    Write-Host "Has IIKit artifacts: $hasIikitArtifacts"
}
