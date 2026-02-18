#!/usr/bin/env bash
#
# Prepare tile for publishing — makes skills self-contained.
# Used by CI and by run-tile-tests.sh --from-local for CI/local parity.
#
# Usage:
#   ./tests/prepare-tile.sh <tile-skills-dir>
#
# The <tile-skills-dir> must contain iikit-*/ skill directories with
# iikit-core/ as the source of shared references and templates.
#

set -euo pipefail

SKILLS_DIR="${1:?Usage: prepare-tile.sh <tile-skills-dir>}"

if [[ ! -d "$SKILLS_DIR/iikit-core" ]]; then
    echo "ERROR: $SKILLS_DIR/iikit-core not found" >&2
    exit 1
fi

cd "$SKILLS_DIR"

# Step 1: Copy referenced files from iikit-core into each skill and rewrite links
for skill_dir in iikit-*/; do
    [ "$skill_dir" = "iikit-core/" ] && continue
    skill_md="$skill_dir/SKILL.md"
    [ ! -f "$skill_md" ] && continue

    for subdir in references templates; do
        if grep -q "../iikit-core/$subdir/" "$skill_md"; then
            mkdir -p "$skill_dir/$subdir"
            # Extract filenames — use grep -oE for portability (works on macOS and Linux)
            grep -oE "\.\./iikit-core/$subdir/[a-z-]+\.md" "$skill_md" | \
                sed "s|../iikit-core/$subdir/||" | sort -u | while read -r file; do
                if [ -f "iikit-core/$subdir/$file" ]; then
                    cp "iikit-core/$subdir/$file" "$skill_dir/$subdir/$file"
                    echo "  Copied $subdir/$file → $skill_dir$subdir/"
                fi
            done
            # Rewrite links: ../iikit-core/subdir/file.md → ./subdir/file.md
            # Use sed with backup extension for macOS/Linux portability
            if sed --version 2>/dev/null | grep -q GNU; then
                sed -i "s|\.\./iikit-core/$subdir/|./$subdir/|g" "$skill_md"
            else
                sed -i '' "s|\.\./iikit-core/$subdir/|./$subdir/|g" "$skill_md"
            fi
        fi
    done
    echo "✓ $skill_dir is self-contained"
done

# Step 2: Clean up iikit-core — distributed files no longer needed in published tile
rm -rf iikit-core/references
echo "✓ Removed iikit-core/references/ (fully distributed)"

# Remove templates only referenced from SKILL.md (now distributed as local copies)
# Keep templates referenced by scripts: agent-file-template.md, spec-template.md, plan-template.md
for tmpl in constitution-template.md checklist-template.md tasks-template.md testspec-template.md; do
    rm -f "iikit-core/templates/$tmpl"
done
echo "✓ Removed distributed-only templates from iikit-core/templates/"
