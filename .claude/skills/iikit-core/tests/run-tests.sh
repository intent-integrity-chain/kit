#!/usr/bin/env bash
# Run all bash tests using bats
#
# Prerequisites:
#   - bats-core: brew install bats-core (macOS) or apt install bats (Linux)
#   - jq: brew install jq (macOS) or apt install jq (Linux)
#
# Usage:
#   ./run-tests.sh           # Run all tests
#   ./run-tests.sh common    # Run specific test file
#   ./run-tests.sh -v        # Verbose output

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASH_TESTS_DIR="$SCRIPT_DIR/bash"

# Check for bats
if ! command -v bats &> /dev/null; then
    echo "ERROR: bats-core is not installed."
    echo ""
    echo "Install with:"
    echo "  macOS:  brew install bats-core"
    echo "  Ubuntu: apt install bats"
    echo "  npm:    npm install -g bats"
    exit 1
fi

# Check for jq (used in tests)
if ! command -v jq &> /dev/null; then
    echo "WARNING: jq is not installed. Some tests may fail."
    echo "Install with: brew install jq (macOS) or apt install jq (Linux)"
fi

# Parse arguments
VERBOSE=""
TEST_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE="--verbose-run"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] [TEST_FILE]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Verbose output"
            echo "  -h, --help       Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                    Run all tests"
            echo "  $0 common             Run common.bats"
            echo "  $0 -v testify-tdd     Run testify-tdd.bats with verbose output"
            exit 0
            ;;
        *)
            TEST_FILE="$1"
            shift
            ;;
    esac
done

echo "======================================"
echo "  Running Bash Tests (bats)"
echo "======================================"
echo ""

cd "$BASH_TESTS_DIR"

if [[ -n "$TEST_FILE" ]]; then
    # Run specific test file
    if [[ -f "${TEST_FILE}.bats" ]]; then
        bats $VERBOSE "${TEST_FILE}.bats"
    elif [[ -f "$TEST_FILE" ]]; then
        bats $VERBOSE "$TEST_FILE"
    else
        echo "ERROR: Test file not found: $TEST_FILE"
        exit 1
    fi
else
    # Run all tests
    bats $VERBOSE *.bats
fi

echo ""
echo "======================================"
echo "  All Bash tests passed!"
echo "======================================"
