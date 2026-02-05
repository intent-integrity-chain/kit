#!/usr/bin/env bash
#
# Sync source skills to tile distribution
#
# Builds the tile from .claude/skills/ (source of truth) by copying all skill
# directories into tiles/intent-integrity-kit/skills/ and rewriting paths in
# SKILL.md files for the tile context.
#
# Usage:
#   ./scripts/sync-to-tile.sh [--dry-run]
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TILE_NAME="tessl-labs/intent-integrity-kit"
SOURCE_DIR=".claude/skills"
TILE_DIR="tiles/intent-integrity-kit"
TILE_SKILLS_DIR="$TILE_DIR/skills"
TILE_PATH=".tessl/tiles/$TILE_NAME/skills"

DRY_RUN=false

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[ OK ]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERR ]${NC} $1"; }

# Detect sed flavor once (macOS requires -i '', GNU requires -i)
if sed --version 2>/dev/null | grep -q GNU 2>/dev/null; then
    _SED_GNU=true
else
    _SED_GNU=false
fi

sed_inplace() {
    if [[ "$_SED_GNU" == "true" ]]; then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}

# Find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown option: $1"; echo "Usage: $0 [--dry-run]"; exit 1 ;;
    esac
done

# Validate source exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "Source directory not found: $SOURCE_DIR"
    exit 1
fi

if [[ ! -d "$TILE_DIR" ]]; then
    log_error "Tile directory not found: $TILE_DIR"
    exit 1
fi

echo ""
echo "========================================="
echo "  Sync Source Skills to Tile"
echo "========================================="
echo ""
log_info "Source: $SOURCE_DIR"
log_info "Target: $TILE_SKILLS_DIR"
log_info "Tile path prefix: $TILE_PATH"
[[ "$DRY_RUN" == "true" ]] && log_warn "DRY RUN - no changes will be made"
echo ""

# Step 1: Clean tile skills directory and tile-root tests (preserve tile.json, index.md)
log_info "Step 1: Cleaning $TILE_SKILLS_DIR..."

if [[ "$DRY_RUN" == "false" ]]; then
    if [[ -d "$TILE_SKILLS_DIR" ]]; then
        rm -rf "$TILE_SKILLS_DIR"
    fi
    mkdir -p "$TILE_SKILLS_DIR"
    # Remove tile-root tests/ — tests belong in source repo, not published tile
    rm -rf "$TILE_DIR/tests"
fi
log_ok "Cleaned tile skills directory"

# Step 2: Copy all skill directories from source to tile
log_info "Step 2: Copying skill directories..."

files_synced=0
skills_synced=0

for skill_dir in "$SOURCE_DIR"/iikit-*; do
    [[ ! -d "$skill_dir" ]] && continue
    skill_name=$(basename "$skill_dir")

    if [[ "$DRY_RUN" == "false" ]]; then
        # Copy skill directory, excluding tests/ (tests belong in source repo, not tile)
        rsync -a --exclude='tests/' "$skill_dir/" "$TILE_SKILLS_DIR/$skill_name/"
    fi

    count=$(find "$skill_dir" -not -path '*/tests/*' -type f | wc -l)
    count="${count//[^0-9]/}"
    files_synced=$((files_synced + count))
    skills_synced=$((skills_synced + 1))
    log_ok "Copied $skill_name ($count files)"
done

echo ""

# Step 3: Rewrite paths in SKILL.md files only
log_info "Step 3: Rewriting paths in SKILL.md files..."

paths_rewritten=0

for skill_md in "$TILE_SKILLS_DIR"/iikit-*/SKILL.md; do
    [[ ! -f "$skill_md" ]] && continue
    skill_name=$(basename "$(dirname "$skill_md")")

    if [[ "$DRY_RUN" == "true" ]]; then
        # Count what would change
        count=$(grep -c '\.claude/skills/' "$skill_md" 2>/dev/null || echo "0")
        count="${count//[^0-9]/}"
        if [[ "$count" -gt 0 ]]; then
            log_info "Would rewrite $count paths in $skill_name/SKILL.md"
            paths_rewritten=$((paths_rewritten + count))
        fi
        continue
    fi

    # Rewrite bash command paths:
    #   bash .claude/skills/iikit-core/scripts/bash/ -> bash .tessl/tiles/TILE_NAME/skills/iikit-core/scripts/bash/
    sed_inplace "s|bash \.claude/skills/iikit-core/scripts/bash/|bash $TILE_PATH/iikit-core/scripts/bash/|g" "$skill_md"

    # Rewrite pwsh command paths:
    #   pwsh .claude/skills/iikit-core/scripts/powershell/ -> pwsh .tessl/tiles/TILE_NAME/skills/iikit-core/scripts/powershell/
    sed_inplace "s|pwsh \.claude/skills/iikit-core/scripts/powershell/|pwsh $TILE_PATH/iikit-core/scripts/powershell/|g" "$skill_md"

    # Rewrite cp command paths:
    #   cp .claude/skills/iikit-core/templates/ -> cp .tessl/tiles/TILE_NAME/skills/iikit-core/templates/
    sed_inplace "s|cp \.claude/skills/iikit-core/templates/|cp $TILE_PATH/iikit-core/templates/|g" "$skill_md"

    # Rewrite remaining .claude/skills/iikit-core/scripts/ references (e.g. in inline code)
    sed_inplace "s|\.claude/skills/iikit-core/scripts/bash/|$TILE_PATH/iikit-core/scripts/bash/|g" "$skill_md"
    sed_inplace "s|\.claude/skills/iikit-core/scripts/powershell/|$TILE_PATH/iikit-core/scripts/powershell/|g" "$skill_md"

    # Rewrite markdown links to templates:
    #   ](.claude/skills/iikit-core/templates/ -> ](../iikit-core/templates/
    sed_inplace 's|\](\.claude/skills/iikit-core/templates/|](../iikit-core/templates/|g' "$skill_md"

    # Count changes (compare with source)
    local_count=$(diff "$SOURCE_DIR/$skill_name/SKILL.md" "$skill_md" 2>/dev/null | grep -c "^[<>]" || echo "0")
    local_count="${local_count//[^0-9]/}"
    if [[ "$local_count" -gt 0 ]]; then
        paths_rewritten=$((paths_rewritten + local_count / 2))
        log_ok "Rewrote paths in $skill_name/SKILL.md"
    fi
done

echo ""

# Step 4: Validate no .claude/skills/ paths remain in tile SKILL.md files
log_info "Step 4: Validating no source paths remain in tile..."

validation_ok=true
for skill_md in "$TILE_SKILLS_DIR"/iikit-*/SKILL.md; do
    [[ ! -f "$skill_md" ]] && continue
    skill_name=$(basename "$(dirname "$skill_md")")

    remaining=$(grep -c '\.claude/skills/' "$skill_md" 2>/dev/null || echo "0")
    remaining="${remaining//[^0-9]/}"
    if [[ "$remaining" -gt 0 ]]; then
        log_error "$skill_name/SKILL.md still has $remaining .claude/skills/ references"
        grep -n '\.claude/skills/' "$skill_md" | head -3
        validation_ok=false
    fi
done

if [[ "$validation_ok" == "true" ]]; then
    log_ok "No .claude/skills/ paths remain in tile SKILL.md files"
fi

echo ""

# Step 5: Run tessl tile lint
log_info "Step 5: Running tile lint..."

# Use tessl if available, fall back to npx
if command -v tessl &>/dev/null; then
    TESSL_CMD="tessl"
else
    TESSL_CMD="npx @tessl/cli"
fi

if $TESSL_CMD tile lint "$TILE_DIR" 2>&1; then
    log_ok "Tile lint passed"
else
    log_error "Tile lint failed (see above)"
    exit 1
fi

echo ""

# Summary
echo "========================================="
echo "  Sync Summary"
echo "========================================="
echo ""
echo "  Skills synced:    $skills_synced"
echo "  Files copied:     $files_synced"
echo "  Paths rewritten:  $paths_rewritten"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "DRY RUN complete - no changes were made"
elif [[ "$validation_ok" == "true" ]]; then
    log_ok "Sync complete!"
else
    log_error "Sync complete but validation failed - check errors above"
    exit 1
fi
