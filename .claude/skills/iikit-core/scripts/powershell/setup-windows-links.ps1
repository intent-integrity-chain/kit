<#
.SYNOPSIS
    Creates symlinks or junctions for intent-integrity-kit-skills on Windows.

.DESCRIPTION
    This script automates the creation of symbolic links for:
    - .codex/skills -> .claude/skills
    - .gemini/skills -> .claude/skills
    - .opencode/skills -> .claude/skills
    - CLAUDE.md -> AGENTS.md
    - GEMINI.md -> AGENTS.md

    On Windows, symlinks require either:
    - Administrator privileges, OR
    - Developer Mode enabled (Windows 10 build 14972+)

    If symlinks fail, the script falls back to directory junctions (for directories)
    or file copies (for files).

.PARAMETER Force
    Overwrite existing links/directories without prompting.

.EXAMPLE
    .\setup-windows-links.ps1
    Creates all required symlinks with prompts.

.EXAMPLE
    .\setup-windows-links.ps1 -Force
    Creates all required symlinks, overwriting existing ones.
#>

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Get script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..\..") | Select-Object -ExpandProperty Path

Write-Host ""
Write-Host "Intent Integrity Kit Skills - Windows Link Setup" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project root: $ProjectRoot"
Write-Host ""

# Check if we can create symlinks
function Test-SymlinkCapability {
    $testDir = Join-Path $env:TEMP "symlink_test_$(Get-Random)"
    $testLink = Join-Path $env:TEMP "symlink_test_link_$(Get-Random)"

    try {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        New-Item -ItemType SymbolicLink -Path $testLink -Target $testDir -ErrorAction Stop | Out-Null
        Remove-Item $testLink -Force
        Remove-Item $testDir -Force
        return $true
    }
    catch {
        if (Test-Path $testDir) { Remove-Item $testDir -Force -ErrorAction SilentlyContinue }
        if (Test-Path $testLink) { Remove-Item $testLink -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

# Check Developer Mode status
function Test-DeveloperMode {
    try {
        $devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
        return ($devMode.AllowDevelopmentWithoutDevLicense -eq 1)
    }
    catch {
        return $false
    }
}

# Check admin status
function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Create directory link (symlink or junction)
function New-DirectoryLink {
    param(
        [string]$LinkPath,
        [string]$TargetPath,
        [bool]$CanSymlink
    )

    $linkName = Split-Path $LinkPath -Leaf
    $targetName = Split-Path $TargetPath -Leaf

    # Check if link already exists
    if (Test-Path $LinkPath) {
        $item = Get-Item $LinkPath -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            if ($Force) {
                Write-Host "  Removing existing link: $linkName" -ForegroundColor Yellow
                Remove-Item $LinkPath -Force -Recurse
            }
            else {
                Write-Host "  [SKIP] $linkName already exists (use -Force to overwrite)" -ForegroundColor Gray
                return $true
            }
        }
        else {
            Write-Host "  [ERROR] $linkName exists as regular directory" -ForegroundColor Red
            Write-Host "          Remove it manually and re-run this script" -ForegroundColor Red
            return $false
        }
    }

    # Ensure parent directory exists
    $parentDir = Split-Path $LinkPath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    if ($CanSymlink) {
        try {
            New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath -ErrorAction Stop | Out-Null
            Write-Host "  [OK] $linkName -> $targetName (symlink)" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "  [WARN] Symlink failed, trying junction..." -ForegroundColor Yellow
        }
    }

    # Fall back to junction
    try {
        cmd /c mklink /J "$LinkPath" "$TargetPath" 2>&1 | Out-Null
        Write-Host "  [OK] $linkName -> $targetName (junction)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  [ERROR] Failed to create link: $_" -ForegroundColor Red
        return $false
    }
}

# Create file link (symlink or copy)
function New-FileLink {
    param(
        [string]$LinkPath,
        [string]$TargetPath,
        [bool]$CanSymlink
    )

    $linkName = Split-Path $LinkPath -Leaf
    $targetName = Split-Path $TargetPath -Leaf

    # Check if link already exists
    if (Test-Path $LinkPath) {
        $item = Get-Item $LinkPath -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            if ($Force) {
                Write-Host "  Removing existing link: $linkName" -ForegroundColor Yellow
                Remove-Item $LinkPath -Force
            }
            else {
                Write-Host "  [SKIP] $linkName already exists (use -Force to overwrite)" -ForegroundColor Gray
                return $true
            }
        }
        else {
            if ($Force) {
                Write-Host "  Removing existing file: $linkName" -ForegroundColor Yellow
                Remove-Item $LinkPath -Force
            }
            else {
                Write-Host "  [SKIP] $linkName exists as regular file (use -Force to overwrite)" -ForegroundColor Gray
                return $true
            }
        }
    }

    if ($CanSymlink) {
        try {
            New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath -ErrorAction Stop | Out-Null
            Write-Host "  [OK] $linkName -> $targetName (symlink)" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "  [WARN] Symlink failed, creating copy instead..." -ForegroundColor Yellow
        }
    }

    # Fall back to copy with warning
    try {
        Copy-Item -Path $TargetPath -Destination $LinkPath -Force
        Write-Host "  [OK] $linkName (copy of $targetName)" -ForegroundColor Yellow
        Write-Host "       Note: Changes to AGENTS.md won't auto-sync to $linkName" -ForegroundColor Yellow
        return $true
    }
    catch {
        Write-Host "  [ERROR] Failed to create file: $_" -ForegroundColor Red
        return $false
    }
}

# Main execution
$isAdmin = Test-Administrator
$isDeveloperMode = Test-DeveloperMode
$canSymlink = Test-SymlinkCapability

Write-Host "System Status:" -ForegroundColor White
Write-Host "  Administrator:   $(if ($isAdmin) { 'Yes' } else { 'No' })"
Write-Host "  Developer Mode:  $(if ($isDeveloperMode) { 'Yes' } else { 'No' })"
Write-Host "  Can Symlink:     $(if ($canSymlink) { 'Yes' } else { 'No (will use junctions)' })"
Write-Host ""

if (-not $canSymlink -and -not $isAdmin) {
    Write-Host "TIP: Enable Developer Mode for symlink support without admin rights:" -ForegroundColor Cyan
    Write-Host "     Settings > Update & Security > For developers > Developer Mode" -ForegroundColor Cyan
    Write-Host ""
}

# Directory links
Write-Host "Creating directory links..." -ForegroundColor White

$dirLinks = @(
    @{ Link = ".codex\skills"; Target = ".claude\skills" },
    @{ Link = ".gemini\skills"; Target = ".claude\skills" },
    @{ Link = ".opencode\skills"; Target = ".claude\skills" }
)

$success = $true
foreach ($link in $dirLinks) {
    $linkPath = Join-Path $ProjectRoot $link.Link
    $targetPath = Join-Path $ProjectRoot $link.Target

    if (-not (New-DirectoryLink -LinkPath $linkPath -TargetPath $targetPath -CanSymlink $canSymlink)) {
        $success = $false
    }
}

Write-Host ""
Write-Host "Creating file links..." -ForegroundColor White

$fileLinks = @(
    @{ Link = "CLAUDE.md"; Target = "AGENTS.md" },
    @{ Link = "GEMINI.md"; Target = "AGENTS.md" }
)

foreach ($link in $fileLinks) {
    $linkPath = Join-Path $ProjectRoot $link.Link
    $targetPath = Join-Path $ProjectRoot $link.Target

    if (-not (New-FileLink -LinkPath $linkPath -TargetPath $targetPath -CanSymlink $canSymlink)) {
        $success = $false
    }
}

Write-Host ""
if ($success) {
    Write-Host "Setup complete!" -ForegroundColor Green
}
else {
    Write-Host "Setup completed with some errors. Review the output above." -ForegroundColor Yellow
}
Write-Host ""
