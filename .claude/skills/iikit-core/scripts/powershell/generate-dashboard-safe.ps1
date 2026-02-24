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
$OutputFile = Join-Path $ProjectDir ".specify" "dashboard.html"

# Find the dashboard generator (dev layout or published self-contained layout)
$Generator = $null
$candidateDirs = @(
    (Join-Path (Split-Path $ScriptDir -Parent) "dashboard"),
    (Join-Path $ScriptDir ".." ".." ".." "iikit-core" "scripts" "dashboard")
)
foreach ($dir in $candidateDirs) {
    $candidate = Join-Path $dir "generate-dashboard.js"
    if (Test-Path $candidate) {
        $Generator = $candidate
        break
    }
}

# Check if node is available
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    exit 0
}

# Check if generator was found
if (-not $Generator) {
    exit 0
}

# Check if project has CONSTITUTION.md
if (-not (Test-Path (Join-Path $ProjectDir "CONSTITUTION.md"))) {
    exit 0
}

# Generate dashboard — log errors instead of swallowing them
$DashboardLog = Join-Path $ProjectDir ".specify" "dashboard.log"
try {
    node $Generator $ProjectDir 2>$DashboardLog
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "[iikit] Dashboard generation failed. See $DashboardLog"
    } elseif ((Test-Path $DashboardLog) -and (Get-Item $DashboardLog).Length -eq 0) {
        Remove-Item $DashboardLog -ErrorAction SilentlyContinue
    }
} catch {
    Write-Warning "[iikit] Dashboard generation failed: $_"
}

# Start background watcher if not already running (requires chokidar)
$WatcherPidFile = Join-Path $ProjectDir ".specify" ".dashboard-watcher.pid"
$watcherRunning = $false
if (Test-Path $WatcherPidFile) {
    $existingPid = Get-Content $WatcherPidFile -ErrorAction SilentlyContinue
    if ($existingPid) {
        try {
            $proc = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
            if ($proc) { $watcherRunning = $true }
        } catch {}
    }
    if (-not $watcherRunning) { Remove-Item $WatcherPidFile -ErrorAction SilentlyContinue }
}

if (-not $watcherRunning -and $Generator) {
    try {
        $watchProc = Start-Process -FilePath "node" -ArgumentList "$Generator", "$ProjectDir", "--watch" -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $ProjectDir ".specify" "dashboard-watcher.log") -RedirectStandardError (Join-Path $ProjectDir ".specify" "dashboard-watcher-err.log")
        Start-Sleep -Milliseconds 500
        if (-not $watchProc.HasExited) {
            Set-Content -Path $WatcherPidFile -Value $watchProc.Id
        }
    } catch {}
}

# Dashboard generated — the skill will suggest the user open it

exit 0
