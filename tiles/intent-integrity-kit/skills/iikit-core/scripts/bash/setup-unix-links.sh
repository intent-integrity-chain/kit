#!/usr/bin/env bash
#
# setup-unix-links.sh - Creates symlinks for intent-integrity-kit on Unix/macOS/Linux
#
# DESCRIPTION:
#   This script automates the creation of symbolic links for:
#   - .codex/skills -> .claude/skills
#   - .gemini/skills -> .claude/skills
#   - .opencode/skills -> .claude/skills
#   - CLAUDE.md -> AGENTS.md
#   - GEMINI.md -> AGENTS.md
#
# USAGE:
#   ./setup-unix-links.sh           # Create symlinks with prompts
#   ./setup-unix-links.sh -f        # Force overwrite existing links
#   ./setup-unix-links.sh --force   # Force overwrite existing links
#   ./setup-unix-links.sh --project-root /path  # Specify project root
#
# EXIT CODES:
#   0 - Success
#   1 - Partial failure (some links failed)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Parse arguments
FORCE=false
PROJECT_ROOT_ARG=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        --project-root)
            PROJECT_ROOT_ARG="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-f|--force] [--project-root PATH]"
            echo ""
            echo "Creates symlinks for multi-agent support in intent-integrity-kit."
            echo ""
            echo "Options:"
            echo "  -f, --force          Overwrite existing links without prompting"
            echo "  --project-root PATH  Specify project root directory"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "$PROJECT_ROOT_ARG" ]]; then
    PROJECT_ROOT="$(cd "$PROJECT_ROOT_ARG" && pwd)"
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

echo ""
echo -e "${CYAN}Intent Integrity Kit - Unix Link Setup${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""
echo "Project root: $PROJECT_ROOT"
echo ""

# Track success
SUCCESS=true

# Create directory symlink
create_dir_link() {
    local link_path="$1"
    local target_path="$2"
    local link_name
    local target_name
    link_name=$(basename "$link_path")
    target_name=$(basename "$target_path")

    # Check if link already exists
    if [[ -L "$link_path" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            echo -e "  ${YELLOW}Removing existing link: $link_name${NC}"
            rm -f "$link_path"
        else
            echo -e "  ${GRAY}[SKIP] $link_name already exists (use -f to overwrite)${NC}"
            return 0
        fi
    elif [[ -d "$link_path" ]]; then
        echo -e "  ${RED}[ERROR] $link_name exists as regular directory${NC}"
        echo -e "  ${RED}        Remove it manually and re-run this script${NC}"
        return 1
    fi

    # Ensure parent directory exists
    local parent_dir
    parent_dir=$(dirname "$link_path")
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir"
    fi

    # Create symlink with relative path
    local relative_target
    relative_target=$(realpath --relative-to="$parent_dir" "$target_path" 2>/dev/null || \
                      python3 -c "import os.path; print(os.path.relpath('$target_path', '$parent_dir'))" 2>/dev/null || \
                      echo "$target_path")

    if ln -s "$relative_target" "$link_path" 2>/dev/null; then
        echo -e "  ${GREEN}[OK] $link_name -> $target_name (symlink)${NC}"
        return 0
    else
        echo -e "  ${RED}[ERROR] Failed to create symlink: $link_name${NC}"
        return 1
    fi
}

# Create file symlink
create_file_link() {
    local link_path="$1"
    local target_path="$2"
    local link_name
    local target_name
    link_name=$(basename "$link_path")
    target_name=$(basename "$target_path")

    # Check if link already exists
    if [[ -L "$link_path" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            echo -e "  ${YELLOW}Removing existing link: $link_name${NC}"
            rm -f "$link_path"
        else
            echo -e "  ${GRAY}[SKIP] $link_name already exists (use -f to overwrite)${NC}"
            return 0
        fi
    elif [[ -f "$link_path" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            echo -e "  ${YELLOW}Removing existing file: $link_name${NC}"
            rm -f "$link_path"
        else
            echo -e "  ${GRAY}[SKIP] $link_name exists as regular file (use -f to overwrite)${NC}"
            return 0
        fi
    fi

    # Create symlink with relative path (files are in same directory)
    if ln -s "$target_name" "$link_path" 2>/dev/null; then
        echo -e "  ${GREEN}[OK] $link_name -> $target_name (symlink)${NC}"
        return 0
    else
        echo -e "  ${RED}[ERROR] Failed to create symlink: $link_name${NC}"
        return 1
    fi
}

# Create directory links
echo -e "${WHITE}Creating directory links...${NC}"

declare -a DIR_LINKS=(
    ".codex/skills:.claude/skills"
    ".gemini/skills:.claude/skills"
    ".opencode/skills:.claude/skills"
)

for link_spec in "${DIR_LINKS[@]}"; do
    link_rel="${link_spec%%:*}"
    target_rel="${link_spec##*:}"
    link_path="$PROJECT_ROOT/$link_rel"
    target_path="$PROJECT_ROOT/$target_rel"

    if ! create_dir_link "$link_path" "$target_path"; then
        SUCCESS=false
    fi
done

echo ""
echo -e "${WHITE}Creating file links...${NC}"

declare -a FILE_LINKS=(
    "CLAUDE.md:AGENTS.md"
    "GEMINI.md:AGENTS.md"
)

for link_spec in "${FILE_LINKS[@]}"; do
    link_rel="${link_spec%%:*}"
    target_rel="${link_spec##*:}"
    link_path="$PROJECT_ROOT/$link_rel"
    target_path="$PROJECT_ROOT/$target_rel"

    if ! create_file_link "$link_path" "$target_path"; then
        SUCCESS=false
    fi
done

echo ""
if [[ "$SUCCESS" == "true" ]]; then
    echo -e "${GREEN}Setup complete!${NC}"
    exit 0
else
    echo -e "${YELLOW}Setup completed with some errors. Review the output above.${NC}"
    exit 1
fi
