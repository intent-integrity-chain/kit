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

# Generate dashboard
try {
    node $Generator $ProjectDir 2>$null
} catch {
    exit 0
}
if ($LASTEXITCODE -ne 0) { exit 0 }

# Dashboard generated — the skill will suggest the user open it

exit 0
