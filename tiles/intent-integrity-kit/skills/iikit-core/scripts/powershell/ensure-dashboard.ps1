#!/usr/bin/env pwsh

# Ensure the iikit-dashboard process is running (idempotent)
#
# Usage: ./ensure-dashboard.ps1
#
# If iikit-dashboard is already running, exits silently.
# If not running, starts it on the first available port from 3000.
# Never fails — exits 0 even if npx is unavailable.

$ErrorActionPreference = 'SilentlyContinue'

# 1. Check if already running
$existing = Get-Process -Name "node" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'iikit-dashboard' }
if ($existing) {
    exit 0
}

# 2. Check npx available
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    exit 0
}

# 3. Find first available port starting from 3000
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

# 4. Start dashboard in background
Start-Process npx -ArgumentList "iikit-dashboard", "--port", "$port", "." -NoNewWindow -RedirectStandardOutput ([System.IO.Path]::GetTempFileName()) -RedirectStandardError ([System.IO.Path]::GetTempFileName())

exit 0
