#!/usr/bin/env bash

# Ensure the iikit-dashboard process is running (idempotent)
#
# Usage: ./ensure-dashboard.sh
#
# If iikit-dashboard is already running for THIS project, exits silently.
# If not running, starts it on the first available port from 3000.
# Never fails — exits 0 even if npx is unavailable.
#
# Uses .specify/dashboard.pid.json for per-project instance tracking.
# See: https://github.com/intent-integrity-chain/iikit-dashboard/issues/22

# Do not set -e: this script must never fail
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"
PIDFILE="$PROJECT_DIR/.specify/dashboard.pid.json"

# 1. Check if already running for THIS project via pidfile
if [ -f "$PIDFILE" ]; then
    pid=$(grep -o '"pid":[[:space:]]*[0-9]*' "$PIDFILE" 2>/dev/null | grep -o '[0-9]*')
    port=$(grep -o '"port":[[:space:]]*[0-9]*' "$PIDFILE" 2>/dev/null | grep -o '[0-9]*')
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && \
       [ -n "$port" ] && curl -sf --max-time 2 "http://127.0.0.1:$port/" >/dev/null 2>&1; then
        exit 0
    fi
    # Stale pidfile (process dead or port not responding) — remove it
    rm -f "$PIDFILE"
fi

# 2. Check npx available
if ! command -v npx >/dev/null 2>&1; then
    exit 0
fi

# 3. Ensure .specify directory exists
mkdir -p "$PROJECT_DIR/.specify"

# 4. Find first available port starting from 3000
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

# 5. Start dashboard in background (always latest version)
npx --yes iikit-dashboard@latest --port "$PORT" "$PROJECT_DIR" >/dev/null 2>&1 &
DASHBOARD_PID=$!

# 6. Write pidfile for this project (dashboard may overwrite with richer data)
cat > "$PIDFILE" <<PIDJSON
{
  "pid": $DASHBOARD_PID,
  "port": $PORT,
  "directory": "$PROJECT_DIR",
  "startedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
}
PIDJSON

exit 0
