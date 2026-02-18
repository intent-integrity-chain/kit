#!/usr/bin/env bash

# Ensure the iikit-dashboard process is running (idempotent)
#
# Usage: ./ensure-dashboard.sh
#
# If iikit-dashboard is already running, exits silently.
# If not running, starts it on the first available port from 3000.
# Never fails — exits 0 even if npx is unavailable.

# Do not set -e: this script must never fail
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Check if already running
if pgrep -f "node.*iikit-dashboard" >/dev/null 2>&1; then
    exit 0
fi

# 2. Check npx available
if ! command -v npx >/dev/null 2>&1; then
    exit 0
fi

# 3. Find first available port starting from 3000
find_available_port() {
    local port=3000
    while [ "$port" -le 3100 ]; do
        if ! lsof -i :"$port" >/dev/null 2>&1; then
            echo "$port"
            return 0
        fi
        port=$((port + 1))
    done
    # Fallback: let the dashboard pick its own port
    echo "3000"
}

PORT=$(find_available_port)

# 4. Start dashboard in background
npx iikit-dashboard --port "$PORT" . >/dev/null 2>&1 &

exit 0
