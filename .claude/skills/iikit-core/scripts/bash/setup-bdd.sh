#!/usr/bin/env bash
# BDD Framework Scaffolding
# Auto-detects BDD framework from plan.md and scaffolds directory structure + dependencies
# Usage: setup-bdd.sh [--json] <features-dir> <plan-file>

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# FRAMEWORK DETECTION
# =============================================================================

# Detect BDD framework from plan.md tech stack
# Returns: "framework_name|language" or empty string if none detected
detect_framework() {
    local plan_file="$1"

    if [[ ! -f "$plan_file" ]]; then
        echo ""
        return
    fi

    local content
    content=$(cat "$plan_file")

    # Python + pytest-bdd
    if echo "$content" | grep -qi "pytest-bdd"; then
        echo "pytest-bdd|python"
        return
    fi

    # Python + behave
    if echo "$content" | grep -qi "behave"; then
        echo "behave|python"
        return
    fi

    # JavaScript/TypeScript + Cucumber
    if echo "$content" | grep -qi "@cucumber/cucumber\|cucumber-js\|cucumber\.js"; then
        echo "@cucumber/cucumber|javascript"
        return
    fi

    # Go + godog
    if echo "$content" | grep -qi "godog"; then
        echo "godog|go"
        return
    fi

    # Java + Maven + Cucumber-JVM
    if echo "$content" | grep -qi "cucumber" && echo "$content" | grep -qi "maven\|pom\.xml"; then
        echo "cucumber-jvm-maven|java"
        return
    fi

    # Java + Gradle + Cucumber-JVM
    if echo "$content" | grep -qi "cucumber" && echo "$content" | grep -qi "gradle"; then
        echo "cucumber-jvm-gradle|java"
        return
    fi

    # Rust + cucumber-rs
    if echo "$content" | grep -qi "cucumber-rs\|cucumber.*rust\|rust.*cucumber"; then
        echo "cucumber-rs|rust"
        return
    fi

    # C# + Reqnroll
    if echo "$content" | grep -qi "reqnroll"; then
        echo "reqnroll|csharp"
        return
    fi

    # Fallback: detect language from plan.md and infer framework
    # Python without explicit BDD framework
    if echo "$content" | grep -qi "python\|pytest"; then
        echo "pytest-bdd|python"
        return
    fi

    # JavaScript/TypeScript without explicit BDD framework
    if echo "$content" | grep -qi "javascript\|typescript\|node\.js\|jest\|vitest"; then
        echo "@cucumber/cucumber|javascript"
        return
    fi

    # Go without explicit BDD framework
    if echo "$content" | grep -qi "golang\|go test\|go 1\.\|**Language/Version**: Go"; then
        echo "godog|go"
        return
    fi

    # Java without explicit BDD framework
    if echo "$content" | grep -qiE "java[^s].*(jdk|jre|spring|maven|gradle)"; then
        # Determine build tool
        if echo "$content" | grep -qi "gradle"; then
            echo "cucumber-jvm-gradle|java"
        else
            echo "cucumber-jvm-maven|java"
        fi
        return
    fi

    # Rust without explicit BDD framework
    if echo "$content" | grep -qi "rust\|cargo"; then
        echo "cucumber-rs|rust"
        return
    fi

    # C# without explicit BDD framework
    if echo "$content" | grep -qi "c#\|csharp\|\.net\|dotnet"; then
        echo "reqnroll|csharp"
        return
    fi

    echo ""
}

# =============================================================================
# EXISTING SCAFFOLDING CHECK
# =============================================================================

# Check if BDD scaffolding already exists
# Returns: "true" if both directories exist, "false" otherwise
check_existing_scaffolding() {
    local features_dir="$1"
    local step_defs_dir
    step_defs_dir="$(dirname "$features_dir")/step_definitions"

    if [[ -d "$features_dir" ]] && [[ -d "$step_defs_dir" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# =============================================================================
# DIRECTORY CREATION
# =============================================================================

create_directories() {
    local features_dir="$1"
    local step_defs_dir
    step_defs_dir="$(dirname "$features_dir")/step_definitions"
    local created=()

    if [[ ! -d "$features_dir" ]]; then
        mkdir -p "$features_dir"
        created+=("$(basename "$(dirname "$features_dir")")/features")
    fi

    if [[ ! -d "$step_defs_dir" ]]; then
        mkdir -p "$step_defs_dir"
        created+=("$(basename "$(dirname "$features_dir")")/step_definitions")
    fi

    # Output as JSON array
    local first=true
    printf '['
    for dir in "${created[@]}"; do
        if $first; then
            first=false
        else
            printf ','
        fi
        printf '"%s"' "$dir"
    done
    printf ']'
}

# =============================================================================
# FRAMEWORK INSTALLATION
# =============================================================================

# Install the BDD framework
# Returns: JSON array of installed packages, or instruction message
install_framework() {
    local framework="$1"
    local installed=()
    local instructions=""

    case "$framework" in
        pytest-bdd)
            if command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1; then
                local pip_cmd="pip"
                command -v pip3 >/dev/null 2>&1 && pip_cmd="pip3"
                $pip_cmd install pytest-bdd >/dev/null 2>&1 && installed+=("pytest-bdd")
            fi
            ;;
        behave)
            if command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1; then
                local pip_cmd="pip"
                command -v pip3 >/dev/null 2>&1 && pip_cmd="pip3"
                $pip_cmd install behave >/dev/null 2>&1 && installed+=("behave")
            fi
            ;;
        @cucumber/cucumber)
            if command -v npm >/dev/null 2>&1; then
                npm install --save-dev @cucumber/cucumber >/dev/null 2>&1 && installed+=("@cucumber/cucumber")
            fi
            ;;
        godog)
            if command -v go >/dev/null 2>&1; then
                go get github.com/cucumber/godog >/dev/null 2>&1 && installed+=("godog")
            fi
            ;;
        cucumber-jvm-maven)
            instructions="Add Cucumber-JVM dependency to pom.xml: io.cucumber:cucumber-java, io.cucumber:cucumber-junit-platform-engine"
            ;;
        cucumber-jvm-gradle)
            instructions="Add Cucumber-JVM dependency to build.gradle: io.cucumber:cucumber-java, io.cucumber:cucumber-junit-platform-engine"
            ;;
        cucumber-rs)
            instructions="Add cucumber dependency to Cargo.toml: cucumber = { version = \"0.20\" }"
            ;;
        reqnroll)
            if command -v dotnet >/dev/null 2>&1; then
                dotnet add package Reqnroll.NUnit >/dev/null 2>&1 && installed+=("Reqnroll.NUnit")
            fi
            ;;
    esac

    # Output as JSON array of installed packages
    local first=true
    printf '['
    for pkg in "${installed[@]}"; do
        if $first; then
            first=false
        else
            printf ','
        fi
        printf '"%s"' "$pkg"
    done
    printf ']'

    # Return instructions via stderr if needed (caller can capture)
    if [[ -n "$instructions" ]]; then
        echo "$instructions" >&2
    fi
}

# =============================================================================
# JSON OUTPUT
# =============================================================================

output_json() {
    local status="$1"
    local framework="$2"
    local language="$3"
    local dirs_created="$4"
    local pkgs_installed="$5"
    local message="${6:-}"

    if [[ "$status" == "NO_FRAMEWORK" ]]; then
        cat <<EOF
{"status":"NO_FRAMEWORK","framework":null,"language":"unknown","message":"No BDD framework detected for tech stack. Feature files will be generated without framework scaffolding."}
EOF
    else
        cat <<EOF
{"status":"${status}","framework":"${framework}","language":"${language}","directories_created":${dirs_created},"packages_installed":${pkgs_installed},"config_files_created":[]}
EOF
    fi
}

output_human() {
    local status="$1"
    local framework="$2"
    local language="$3"
    local dirs_created="$4"
    local pkgs_installed="$5"
    local message="${6:-}"

    case "$status" in
        SCAFFOLDED)
            echo "[setup-bdd] Scaffolded BDD framework: $framework ($language)"
            echo "  Directories: $dirs_created"
            echo "  Packages: $pkgs_installed"
            ;;
        ALREADY_SCAFFOLDED)
            echo "[setup-bdd] BDD scaffolding already exists for $framework ($language)"
            ;;
        NO_FRAMEWORK)
            echo "[setup-bdd] WARNING: No BDD framework detected for tech stack."
            echo "  Feature files will be generated without framework scaffolding."
            echo "  Directories created: $dirs_created"
            ;;
    esac
}

# =============================================================================
# MAIN
# =============================================================================

JSON_MODE=false
[[ "${1:-}" == "--json" ]] && { JSON_MODE=true; shift; }

FEATURES_DIR="${1:?Usage: setup-bdd.sh [--json] <features-dir> <plan-file>}"
PLAN_FILE="${2:?Usage: setup-bdd.sh [--json] <features-dir> <plan-file>}"

# Detect framework
detection=$(detect_framework "$PLAN_FILE")

if [[ -z "$detection" ]]; then
    # NO_FRAMEWORK fallback: create directories but no framework install
    dirs_created=$(create_directories "$FEATURES_DIR")

    if $JSON_MODE; then
        output_json "NO_FRAMEWORK" "" "" "$dirs_created" "[]"
    else
        output_human "NO_FRAMEWORK" "" "" "$dirs_created" "[]"
    fi
    exit 0
fi

# Parse detection result
framework="${detection%%|*}"
language="${detection##*|}"

# Check for existing scaffolding (idempotency)
already_scaffolded=$(check_existing_scaffolding "$FEATURES_DIR")

if [[ "$already_scaffolded" == "true" ]]; then
    if $JSON_MODE; then
        output_json "ALREADY_SCAFFOLDED" "$framework" "$language" "[]" "[]"
    else
        output_human "ALREADY_SCAFFOLDED" "$framework" "$language" "[]" "[]"
    fi
    exit 0
fi

# Create directories
dirs_created=$(create_directories "$FEATURES_DIR")

# Install framework (capture instructions from stderr)
instructions=""
pkgs_installed=$(install_framework "$framework" 2>/dev/null) || pkgs_installed="[]"

# Output result
if $JSON_MODE; then
    output_json "SCAFFOLDED" "$framework" "$language" "$dirs_created" "$pkgs_installed"
else
    output_human "SCAFFOLDED" "$framework" "$language" "$dirs_created" "$pkgs_installed"
fi

exit 0
