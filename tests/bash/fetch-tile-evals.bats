#!/usr/bin/env bats
# Tests for fetch-tile-evals.sh

load 'test_helper'

FETCH_EVALS_SCRIPT="$SCRIPTS_DIR/fetch-tile-evals.sh"

setup() {
    setup_test_dir
    # Save original PATH to restore in teardown
    ORIG_PATH="$PATH"
}

teardown() {
    PATH="$ORIG_PATH"
    teardown_test_dir
}

# =============================================================================
# Help and usage tests
# =============================================================================

@test "fetch-tile-evals: --help shows usage" {
    run "$FETCH_EVALS_SCRIPT" --help
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage"
    assert_contains "$output" "--json"
    assert_contains "$output" "--run"
}

@test "fetch-tile-evals: -h shows usage" {
    run "$FETCH_EVALS_SCRIPT" -h
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "Usage"
}

# =============================================================================
# Argument validation tests
# =============================================================================

@test "fetch-tile-evals: fails without tile-name" {
    run "$FETCH_EVALS_SCRIPT"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "tile-name argument is required"
}

@test "fetch-tile-evals: fails with invalid tile-name format" {
    # Create a mock tessl command so we get past the CLI check
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/tessl" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
    chmod +x "$TEST_DIR/bin/tessl"
    PATH="$TEST_DIR/bin:$PATH"

    run "$FETCH_EVALS_SCRIPT" "no-slash-tile"
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "workspace/tile format"
}

@test "fetch-tile-evals: rejects unknown options" {
    run "$FETCH_EVALS_SCRIPT" --unknown
    [[ "$status" -eq 1 ]]
    assert_contains "$output" "Unknown option"
}

# =============================================================================
# Tessl CLI availability tests
# =============================================================================

@test "fetch-tile-evals: exits 0 silently when tessl not available" {
    # Ensure tessl is not in PATH
    PATH="/usr/bin:/bin"

    run "$FETCH_EVALS_SCRIPT" "tessl-labs/some-tile"
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "fetch-tile-evals: outputs JSON skip message when tessl not available with --json" {
    PATH="/usr/bin:/bin"

    run "$FETCH_EVALS_SCRIPT" --json "tessl-labs/some-tile"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"status":"skipped"'
    assert_contains "$output" '"reason":"tessl CLI not available"'
}

# =============================================================================
# No evals found tests
# =============================================================================

@test "fetch-tile-evals: handles no evals gracefully with --json" {
    # Create a mock tessl that returns empty list
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/tessl" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "eval" && "$2" == "list" ]]; then
    echo "[]"
    exit 0
fi
exit 1
MOCK
    chmod +x "$TEST_DIR/bin/tessl"
    PATH="$TEST_DIR/bin:$PATH"

    run "$FETCH_EVALS_SCRIPT" --json "tessl-labs/some-tile"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"status":"no_evals"'
    assert_contains "$output" '"tile":"tessl-labs/some-tile"'
}

# =============================================================================
# Eval data parsing tests
# =============================================================================

@test "fetch-tile-evals: parses eval results and outputs JSON summary" {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/tessl" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "eval" && "$2" == "list" ]]; then
    echo '[{"id":"eval-123","status":"completed"}]'
    exit 0
fi
if [[ "$1" == "eval" && "$2" == "view" ]]; then
    cat <<'JSON'
{"score":85,"max_score":100,"scenarios":[{"name":"s1"},{"name":"s2"},{"name":"s3"}],"scored_at":"2026-02-15T10:00:00Z"}
JSON
    exit 0
fi
exit 1
MOCK
    chmod +x "$TEST_DIR/bin/tessl"
    PATH="$TEST_DIR/bin:$PATH"

    run "$FETCH_EVALS_SCRIPT" --json "tessl-labs/some-tile"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"tile":"tessl-labs/some-tile"'
    assert_contains "$output" '"score":85'
    assert_contains "$output" '"max_score":100'
    assert_contains "$output" '"pct":85'
    assert_contains "$output" '"scenarios":3'
    assert_contains "$output" '"scored_at":"2026-02-15T10:00:00Z"'
}

@test "fetch-tile-evals: saves full eval data to .specify/evals/" {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/tessl" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "eval" && "$2" == "list" ]]; then
    echo '[{"id":"eval-456"}]'
    exit 0
fi
if [[ "$1" == "eval" && "$2" == "view" ]]; then
    echo '{"score":92,"max_score":100,"scenarios":[{"name":"s1"}],"scored_at":"2026-02-15"}'
    exit 0
fi
exit 1
MOCK
    chmod +x "$TEST_DIR/bin/tessl"
    PATH="$TEST_DIR/bin:$PATH"

    "$FETCH_EVALS_SCRIPT" --json "tessl-labs/my-tile"

    [[ -f "$TEST_DIR/.specify/evals/tessl-labs--my-tile.json" ]]
    local saved
    saved=$(cat "$TEST_DIR/.specify/evals/tessl-labs--my-tile.json")
    assert_contains "$saved" '"score":92'
}

@test "fetch-tile-evals: creates evals directory if missing" {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/tessl" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "eval" && "$2" == "list" ]]; then
    echo '[{"id":"eval-789"}]'
    exit 0
fi
if [[ "$1" == "eval" && "$2" == "view" ]]; then
    echo '{"score":50,"max_score":100,"scenarios":[],"scored_at":"2026-01-01"}'
    exit 0
fi
exit 1
MOCK
    chmod +x "$TEST_DIR/bin/tessl"
    PATH="$TEST_DIR/bin:$PATH"

    # Ensure evals dir doesn't exist
    rm -rf "$TEST_DIR/.specify/evals"

    "$FETCH_EVALS_SCRIPT" --json "tessl-labs/another-tile"

    [[ -d "$TEST_DIR/.specify/evals" ]]
    [[ -f "$TEST_DIR/.specify/evals/tessl-labs--another-tile.json" ]]
}

# =============================================================================
# Non-JSON output tests
# =============================================================================

@test "fetch-tile-evals: outputs human-readable format without --json" {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/tessl" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "eval" && "$2" == "list" ]]; then
    echo '[{"id":"eval-abc"}]'
    exit 0
fi
if [[ "$1" == "eval" && "$2" == "view" ]]; then
    echo '{"score":75,"max_score":100,"scenarios":[{"name":"s1"},{"name":"s2"}],"scored_at":"2026-02-10"}'
    exit 0
fi
exit 1
MOCK
    chmod +x "$TEST_DIR/bin/tessl"
    PATH="$TEST_DIR/bin:$PATH"

    run "$FETCH_EVALS_SCRIPT" "tessl-labs/some-tile"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" "75/100"
    assert_contains "$output" "75%"
    assert_contains "$output" "2 scenarios"
}

# =============================================================================
# Eval view failure tests
# =============================================================================

@test "fetch-tile-evals: handles eval view failure gracefully" {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/tessl" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "eval" && "$2" == "list" ]]; then
    echo '[{"id":"eval-fail"}]'
    exit 0
fi
if [[ "$1" == "eval" && "$2" == "view" ]]; then
    exit 1
fi
exit 1
MOCK
    chmod +x "$TEST_DIR/bin/tessl"
    PATH="$TEST_DIR/bin:$PATH"

    run "$FETCH_EVALS_SCRIPT" --json "tessl-labs/broken-tile"
    [[ "$status" -eq 0 ]]
    assert_contains "$output" '"status":"fetch_failed"'
}

# =============================================================================
# --run flag tests
# =============================================================================

@test "fetch-tile-evals: --run triggers eval run when no evals exist" {
    mkdir -p "$TEST_DIR/bin"
    local call_log="$TEST_DIR/tessl-calls.log"

    cat > "$TEST_DIR/bin/tessl" <<MOCK
#!/usr/bin/env bash
echo "\$*" >> "$call_log"
if [[ "\$1" == "eval" && "\$2" == "run" ]]; then
    exit 0
fi
if [[ "\$1" == "eval" && "\$2" == "list" ]]; then
    # Return empty first time, then result after run
    if grep -q "eval run" "$call_log" 2>/dev/null; then
        echo '[{"id":"eval-new"}]'
    else
        echo '[]'
    fi
    exit 0
fi
if [[ "\$1" == "eval" && "\$2" == "view" ]]; then
    echo '{"score":60,"max_score":100,"scenarios":[{"name":"s1"}],"scored_at":"2026-02-17"}'
    exit 0
fi
exit 1
MOCK
    chmod +x "$TEST_DIR/bin/tessl"
    PATH="$TEST_DIR/bin:$PATH"

    run "$FETCH_EVALS_SCRIPT" --json --run "tessl-labs/new-tile"
    [[ "$status" -eq 0 ]]

    # Verify eval run was called
    assert_contains "$(cat "$call_log")" "eval run"
}
