#!/usr/bin/env pwsh
# Generate the static dashboard HTML (idempotent, never fails)
#
# Usage: ./generate-dashboard-safe.ps1 [project-path]
#
# Replaces ensure-dashboard.ps1 — no process management, no pidfiles, no ports.
# Just generates .specify/dashboard.html and optionally opens it.

param(
    [Parameter(Position = 0)]
    [string]$ProjectDir = (Get-Location).Path
)

$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$DashboardDir = Join-Path (Split-Path $ScriptDir -Parent) "dashboard"
$Generator = Join-Path $DashboardDir "generate-dashboard.js"
$OutputFile = Join-Path $ProjectDir ".specify" "dashboard.html"

# Check if node is available
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    exit 0
}

# Check if generator exists
if (-not (Test-Path $Generator)) {
    exit 0
}

# Check if project has CONSTITUTION.md
if (-not (Test-Path (Join-Path $ProjectDir "CONSTITUTION.md"))) {
    exit 0
}

# Generate dashboard
try {
    node $Generator $ProjectDir 2>$null
} catch {
    exit 0
}
if ($LASTEXITCODE -ne 0) { exit 0 }

# Open in browser on first generation
$OpenedMarker = Join-Path $ProjectDir ".specify" ".dashboard-opened"
if ((Test-Path $OutputFile) -and -not (Test-Path $OpenedMarker)) {
    New-Item -ItemType File -Path $OpenedMarker -Force | Out-Null

    if ($IsWindows) {
        Start-Process $OutputFile -ErrorAction SilentlyContinue
    } elseif ($IsMacOS) {
        & open $OutputFile 2>$null
    } elseif ($IsLinux) {
        & xdg-open $OutputFile 2>$null
    }
}

exit 0
