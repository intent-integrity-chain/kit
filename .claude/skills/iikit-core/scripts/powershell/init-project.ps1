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

# Check if already a git repo. `--is-inside-work-tree` is true for linked
# worktrees and submodules (where `.git` is a file pointing at the real
# gitdir), so it covers all the layouts `Test-Path .git` misses.
git -C $projectRoot rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    $gitInitialized = $false
    $gitStatus = "already_initialized"
} else {
    # Initialize git
    git init $projectRoot 2>&1 | Out-Null
    $gitInitialized = $true
    $gitStatus = "initialized"
}

# Resolve hooks directory via `git rev-parse --git-path hooks` once and reuse
# everywhere. In a linked worktree or submodule this resolves to the gitdir's
# hooks/ (typically the main repo's `.git/hooks/`), so Install-IIKitHook and
# pre-commit.d/ provisioning land in the same place git actually runs hooks
# from.
$hooksRel = git -C $projectRoot rev-parse --git-path hooks 2>$null
if ($hooksRel) {
    if ([System.IO.Path]::IsPathRooted($hooksRel)) {
        $hooksAbs = $hooksRel
    } else {
        $hooksAbs = Join-Path $projectRoot $hooksRel
    }
} else {
    $hooksAbs = ""
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

    if (-not $hooksAbs) { return $result }

    $bashScriptDir = Join-Path (Split-Path $PSScriptRoot -Parent) "bash"
    $hookSource = Join-Path $bashScriptDir $SourceFile

    if (-not (Test-Path $hookSource)) {
        $result.status = "source_not_found"
        return $result
    }

    $hooksDir = $hooksAbs
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

# Provision pre-commit.d/ extension point (user-supplied formatters, linters, etc.)
# Uses the same resolved `$hooksAbs` as Install-IIKitHook above so the extension
# point and the hook itself land in the same git-managed hooks directory —
# `git rev-parse --git-path hooks` resolves correctly for linked worktrees and
# submodules where `.git` is a file rather than a directory.
$preCommitDProvisioned = $false
if ($hooksAbs) {
    $preCommitDDir = Join-Path $hooksAbs "pre-commit.d"
    if (-not (Test-Path $preCommitDDir)) {
        New-Item -ItemType Directory -Path $preCommitDDir -Force | Out-Null
    }
    $preCommitDReadme = Join-Path $preCommitDDir "README"
    if (-not (Test-Path $preCommitDReadme)) {
        $readmeContent = @'
# IIKit pre-commit extension point — IIKIT-PRE-COMMIT-D
#
# Drop executable scripts in this directory to extend the pre-commit chain
# without removing or disabling IIKit's pre-commit enforcement (which lives
# at .git/hooks/pre-commit by default, or .git/hooks/iikit-pre-commit when
# IIKit was installed alongside an existing user hook).
#
# Each executable in this dir runs BEFORE IIKit's assertion-integrity check,
# so IIKit remains the final gate — mutating a .feature file / test-specs.md
# / context.json from an extension will be caught by the subsequent IIKit
# check against the post-extension staged state. Files are executed in
# deterministic byte-collation order (LC_ALL=C sort); if one fails the rest
# in this dir still run, but the hook exits non-zero after the loop and
# IIKit does not run. Subdirectories, non-executable files, dotfiles,
# and this README are ignored.
#
# Examples:
#   prettier-write   - bunx prettier --write on staged JS/TS files
#   eslint-fix       - eslint --fix on staged sources
#   secret-scan      - gitleaks protect --staged
#
# Each script receives no arguments. Use `git diff --cached --name-only` to
# find staged files. Exit non-zero to block the commit.
#
# Note: this directory is per-clone (not tracked in git). To share extensions
# across the team, commit your scripts under a tracked path (e.g.
# scripts/git-hooks/) and symlink each into .git/hooks/pre-commit.d/
# during onboarding.
'@
        Set-Content -Path $preCommitDReadme -Value $readmeContent -NoNewline
        $preCommitDProvisioned = $true
    }
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
        pre_commit_d_provisioned = $preCommitDProvisioned
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
    if ($preCommitDProvisioned) {
        # Report the resolved path — in worktrees/submodules this differs from
        # `.git/hooks/pre-commit.d/` (the hooks dir lives in the main repo /
        # `.git/modules/<name>/hooks/`).
        $projectRootStr = $projectRoot.ToString()
        if ($preCommitDDir.StartsWith($projectRootStr, [System.StringComparison]::Ordinal)) {
            $displayPath = $preCommitDDir.Substring($projectRootStr.Length).TrimStart([char]'/', [char]'\')
        } else {
            $displayPath = $preCommitDDir
        }
        Write-Output "[specify] Extension point created at $displayPath (drop user-supplied hooks here)"
    }
}
