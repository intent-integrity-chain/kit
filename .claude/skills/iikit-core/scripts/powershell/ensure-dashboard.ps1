#!/usr/bin/env pwsh

# Ensure the iikit-dashboard process is running (idempotent)
#
# Usage: ./ensure-dashboard.ps1
#
# If iikit-dashboard is already running for THIS project, exits silently.
# If not running, starts it on the first available port from 3000.
# Never fails — exits 0 even if npx is unavailable.
#
# Uses .specify/dashboard.pid.json for per-project instance tracking.
# See: https://github.com/intent-integrity-chain/iikit-dashboard/issues/22

$ErrorActionPreference = 'SilentlyContinue'

$ProjectDir = (Get-Location).Path
$PidFile = Join-Path $ProjectDir '.specify' 'dashboard.pid.json'

# 1. Check if already running for THIS project via pidfile
if (Test-Path $PidFile) {
    $pidData = Get-Content $PidFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($pidData -and $pidData.pid -and $pidData.port) {
        $proc = Get-Process -Id $pidData.pid -ErrorAction SilentlyContinue
        $portAlive = $false
        if ($proc) {
            try {
                $client = [System.Net.WebClient]::new()
                $client.DownloadString("http://127.0.0.1:$($pidData.port)/") | Out-Null
                $portAlive = $true
            } catch {}
        }
        if ($proc -and $portAlive) {
            exit 0
        }
    }
    # Stale pidfile (process dead or port not responding) — remove it
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

# 2. Check npx available
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    exit 0
}

# 3. Ensure .specify directory exists
$specifyDir = Join-Path $ProjectDir '.specify'
if (-not (Test-Path $specifyDir)) {
    New-Item -ItemType Directory -Path $specifyDir -Force | Out-Null
}

# 4. Find first available port starting from 3000
function Find-AvailablePort {
    for ($port = 3000; $port -le 3100; $port++) {
        $listener = [System.Net.Sockets.TcpClient]::new()
        try {
            $listener.Connect('127.0.0.1', $port)
            $listener.Close()
            # Port is in use, try next
        } catch {
            # Port is available
            return $port
        }
    }
    return 3000
}

$port = Find-AvailablePort

# 5. Start dashboard in background (always latest version)
$process = Start-Process npx -ArgumentList "--yes", "iikit-dashboard@latest", "--port", "$port", "$ProjectDir" -NoNewWindow -PassThru -RedirectStandardOutput ([System.IO.Path]::GetTempFileName()) -RedirectStandardError ([System.IO.Path]::GetTempFileName())

# 6. Write pidfile for this project (dashboard may overwrite with richer data)
$pidJson = @{
    pid = $process.Id
    port = $port
    directory = $ProjectDir
    startedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.000Z')
} | ConvertTo-Json

Set-Content -Path $PidFile -Value $pidJson

exit 0
