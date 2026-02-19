#!/usr/bin/env bats
# Tests for ensure-dashboard.sh pidfile lifecycle (issue #22)

load 'test_helper'

DASHBOARD_SCRIPT="$SCRIPTS_DIR/ensure-dashboard.sh"

setup() {
    setup_test_dir
    mkdir -p "$TEST_DIR/.specify"
    cd "$TEST_DIR"

    # Default fake binaries directory
    mkdir -p "$TEST_DIR/bin"

    # Fake lsof: all ports available
    cat > "$TEST_DIR/bin/lsof" <<'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT
    chmod +x "$TEST_DIR/bin/lsof"
}

teardown() {
    # Kill any background processes we started
    if [[ -n "$_DASHBOARD_MOCK_PID" ]]; then
        kill "$_DASHBOARD_MOCK_PID" 2>/dev/null || true
    fi
    # Clean up any orphaned sleep processes from fake npx
    pkill -f "sleep 300" 2>/dev/null || true
    # Clean up temp files
    rm -f /tmp/iikit-test-npx-args /tmp/iikit-test-npx-dir
    teardown_test_dir
}

# Helper: create a pidfile with given pid, port, directory
write_pidfile() {
    local pid="${1:-99999}"
    local port="${2:-3000}"
    local dir="${3:-$TEST_DIR}"
    cat > "$TEST_DIR/.specify/dashboard.pid.json" <<JSON
{
  "pid": $pid,
  "port": $port,
  "directory": "$dir",
  "startedAt": "2026-02-18T12:00:00.000Z"
}
JSON
}

# Helper: start a mock process that stays alive (simulates a running dashboard)
start_mock_process() {
    sleep 300 </dev/null >/dev/null 2>&1 &
    _DASHBOARD_MOCK_PID=$!
    echo "$_DASHBOARD_MOCK_PID"
}

# Helper: create a fake npx that records args and runs sleep in background
create_fake_npx() {
    local log_file="$TEST_DIR/npx.log"
    cat > "$TEST_DIR/bin/npx" <<SCRIPT
#!/usr/bin/env bash
echo "NPX_ARGS: \$*" >> "$log_file"
sleep 300 </dev/null >/dev/null 2>&1 &
SCRIPT
    chmod +x "$TEST_DIR/bin/npx"
}

# =============================================================================
# Pidfile detection — stale pidfile removal
# =============================================================================

@test "ensure-dashboard: removes stale pidfile when PID is dead" {
    write_pidfile 99999 3000 "$TEST_DIR"
    [[ -f "$TEST_DIR/.specify/dashboard.pid.json" ]]

    # No npx available — script cleans pidfile then exits
    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]
    [[ ! -f "$TEST_DIR/.specify/dashboard.pid.json" ]]
}

@test "ensure-dashboard: removes pidfile when PID alive but port not responding" {
    local mock_pid
    mock_pid=$(start_mock_process)

    # PID alive but port 3999 has nothing listening — curl will fail
    write_pidfile "$mock_pid" 3999 "$TEST_DIR"

    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]
    [[ ! -f "$TEST_DIR/.specify/dashboard.pid.json" ]]
}

@test "ensure-dashboard: keeps pidfile when PID alive and port responds" {
    local mock_pid
    mock_pid=$(start_mock_process)

    # Fake curl that always succeeds (simulates port responding)
    cat > "$TEST_DIR/bin/curl" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
    chmod +x "$TEST_DIR/bin/curl"

    write_pidfile "$mock_pid" 3000 "$TEST_DIR"

    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]
    # Pidfile should still exist — dashboard is running
    [[ -f "$TEST_DIR/.specify/dashboard.pid.json" ]]
}

# =============================================================================
# No pidfile — launch path
# =============================================================================

@test "ensure-dashboard: no pidfile proceeds to launch" {
    [[ ! -f "$TEST_DIR/.specify/dashboard.pid.json" ]]

    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]
}

# =============================================================================
# Pidfile creation after launch
# =============================================================================

@test "ensure-dashboard: writes pidfile after launch" {
    create_fake_npx

    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]

    # Pidfile should exist with expected fields
    [[ -f "$TEST_DIR/.specify/dashboard.pid.json" ]]
    local content
    content=$(cat "$TEST_DIR/.specify/dashboard.pid.json")
    assert_contains "$content" '"pid"'
    assert_contains "$content" '"port"'
    assert_contains "$content" '"directory"'
    assert_contains "$content" '"startedAt"'
}

@test "ensure-dashboard: pidfile contains absolute project directory" {
    create_fake_npx

    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]

    local content
    content=$(cat "$TEST_DIR/.specify/dashboard.pid.json")
    assert_contains "$content" "$TEST_DIR"
}

@test "ensure-dashboard: pidfile contains correct port when earlier ports in use" {
    create_fake_npx

    # lsof: ports 3000-3002 in use, 3003 available
    cat > "$TEST_DIR/bin/lsof" <<'SCRIPT'
#!/usr/bin/env bash
port=$(echo "$@" | grep -o ':[0-9]*' | tr -d ':')
if [[ "$port" -le 3002 ]]; then
    exit 0
fi
exit 1
SCRIPT
    chmod +x "$TEST_DIR/bin/lsof"

    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]

    local port
    port=$(grep -o '"port":[[:space:]]*[0-9]*' "$TEST_DIR/.specify/dashboard.pid.json" | grep -o '[0-9]*')
    [[ "$port" -eq 3003 ]]
}

@test "ensure-dashboard: pidfile has ISO 8601 startedAt timestamp" {
    create_fake_npx

    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]

    local content
    content=$(cat "$TEST_DIR/.specify/dashboard.pid.json")
    # Match ISO 8601 pattern: YYYY-MM-DDTHH:MM:SS.000Z
    [[ "$content" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z ]]
}

# =============================================================================
# npx invocation
# =============================================================================

@test "ensure-dashboard: calls npx with --yes and @latest" {
    create_fake_npx

    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]

    # Wait briefly for backgrounded npx to write its log
    sleep 0.3
    local log
    log=$(cat "$TEST_DIR/npx.log")
    assert_contains "$log" "--yes"
    assert_contains "$log" "iikit-dashboard@latest"
}

@test "ensure-dashboard: passes absolute project directory to npx, not dot" {
    create_fake_npx

    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]

    # Wait briefly for backgrounded npx to write its log
    sleep 0.3
    local log
    log=$(cat "$TEST_DIR/npx.log")
    assert_contains "$log" "$TEST_DIR"
}

# =============================================================================
# Edge cases
# =============================================================================

@test "ensure-dashboard: exits 0 when npx not available" {
    # bin dir has no npx
    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]
}

@test "ensure-dashboard: creates .specify directory if missing" {
    rm -rf "$TEST_DIR/.specify"
    create_fake_npx

    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]
    [[ -d "$TEST_DIR/.specify" ]]
}

@test "ensure-dashboard: exits 0 even with corrupt pidfile" {
    echo "CORRUPT JSON{{{" > "$TEST_DIR/.specify/dashboard.pid.json"

    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]
}

@test "ensure-dashboard: cleans corrupt pidfile before proceeding" {
    echo "CORRUPT JSON{{{" > "$TEST_DIR/.specify/dashboard.pid.json"

    PATH="$TEST_DIR/bin:/usr/bin:/bin" run "$DASHBOARD_SCRIPT"
    [[ "$status" -eq 0 ]]

    # Corrupt file should be gone (removed as stale since pid/port extraction fails)
    if [[ -f "$TEST_DIR/.specify/dashboard.pid.json" ]]; then
        # If it exists, it should be a fresh one (not the corrupt content)
        assert_not_contains "$(cat "$TEST_DIR/.specify/dashboard.pid.json")" "CORRUPT"
    fi
}
