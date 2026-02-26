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
    # Transitive ref dep: constitution-loading.md references model-recommendations.md
    if [[ -f "$skill_dir/references/constitution-loading.md" && -f "iikit-core/references/model-recommendations.md" ]]; then
        cp "iikit-core/references/model-recommendations.md" "$skill_dir/references/model-recommendations.md"
        echo "  Copied references/model-recommendations.md → ${skill_dir}references/ (transitive dep)"
    fi

    echo "✓ $skill_dir references self-contained"
done

# Step 2: Copy referenced scripts from iikit-core into each skill and rewrite paths
for skill_dir in iikit-*/; do
    [ "$skill_dir" = "iikit-core/" ] && continue
    skill_md="$skill_dir/SKILL.md"
    [ ! -f "$skill_md" ] && continue

    skill_name="${skill_dir%/}"

    # Extract bash script filenames referenced in SKILL.md
    bash_scripts=$(grep -oE "iikit-core/scripts/bash/[a-z-]+\.sh" "$skill_md" | \
        sed 's|iikit-core/scripts/bash/||' | sort -u) || true

    # Extract powershell script filenames referenced in SKILL.md
    ps_scripts=$(grep -oE "iikit-core/scripts/powershell/[a-z-]+\.ps1" "$skill_md" | \
        sed 's|iikit-core/scripts/powershell/||' | sort -u) || true

    # Skip if no scripts referenced
    if [[ -z "$bash_scripts" && -z "$ps_scripts" ]]; then
        continue
    fi

    # Always add common.sh/common.ps1 (sourced by every script via $SCRIPT_DIR/common.sh)
    if [[ -n "$bash_scripts" ]] && ! echo "$bash_scripts" | grep -q "^common\.sh$"; then
        bash_scripts="$bash_scripts
common.sh"
    fi
    if [[ -n "$ps_scripts" ]] && ! echo "$ps_scripts" | grep -q "^common\.ps1$"; then
        ps_scripts="$ps_scripts
common.ps1"
    fi

    # Add generate-dashboard-safe when check-prerequisites is present (transitive dep —
    # check-prerequisites.sh calls bash "$SCRIPT_DIR/generate-dashboard-safe.sh" at runtime)
    if [[ -n "$bash_scripts" ]] && echo "$bash_scripts" | grep -q "^check-prerequisites\.sh$" && \
       ! echo "$bash_scripts" | grep -q "^generate-dashboard-safe\.sh$"; then
        bash_scripts="$bash_scripts
generate-dashboard-safe.sh"
    fi
    if [[ -n "$ps_scripts" ]] && echo "$ps_scripts" | grep -q "^check-prerequisites\.ps1$" && \
       ! echo "$ps_scripts" | grep -q "^generate-dashboard-safe\.ps1$"; then
        ps_scripts="$ps_scripts
generate-dashboard-safe.ps1"
    fi

    # Add next-step when check-prerequisites is present (transitive dep —
    # check-prerequisites.sh calls bash "$SCRIPT_DIR/next-step.sh" at runtime)
    if [[ -n "$bash_scripts" ]] && echo "$bash_scripts" | grep -q "^check-prerequisites\.sh$" && \
       ! echo "$bash_scripts" | grep -q "^next-step\.sh$"; then
        bash_scripts="$bash_scripts
next-step.sh"
    fi
    if [[ -n "$ps_scripts" ]] && echo "$ps_scripts" | grep -q "^check-prerequisites\.ps1$" && \
       ! echo "$ps_scripts" | grep -q "^next-step\.ps1$"; then
        ps_scripts="$ps_scripts
next-step.ps1"
    fi

    # Add next-step when session-context-hook is present (transitive dep —
    # session hooks call bash "$SCRIPT_DIR/next-step.sh" at runtime)
    if [[ -n "$bash_scripts" ]] && echo "$bash_scripts" | grep -q "^session-context-hook\.sh$" && \
       ! echo "$bash_scripts" | grep -q "^next-step\.sh$"; then
        bash_scripts="$bash_scripts
next-step.sh"
    fi

    # Copy bash scripts
    if [[ -n "$bash_scripts" ]]; then
        mkdir -p "$skill_dir/scripts/bash"
        echo "$bash_scripts" | while read -r script; do
            [[ -z "$script" ]] && continue
            if [ -f "iikit-core/scripts/bash/$script" ]; then
                cp "iikit-core/scripts/bash/$script" "$skill_dir/scripts/bash/$script"
                echo "  Copied scripts/bash/$script → ${skill_dir}scripts/bash/"
            fi
        done
    fi

    # Copy powershell scripts
    if [[ -n "$ps_scripts" ]]; then
        mkdir -p "$skill_dir/scripts/powershell"
        echo "$ps_scripts" | while read -r script; do
            [[ -z "$script" ]] && continue
            if [ -f "iikit-core/scripts/powershell/$script" ]; then
                cp "iikit-core/scripts/powershell/$script" "$skill_dir/scripts/powershell/$script"
                echo "  Copied scripts/powershell/$script → ${skill_dir}scripts/powershell/"
            fi
        done
    fi

    # Copy script→template dependencies if not already present
    # Scripts use $SCRIPT_DIR/../../templates/<tmpl> — must exist at <skill>/templates/
    if echo "$bash_scripts" | grep -q "^check-prerequisites\.sh$"; then
        if [[ -f "iikit-core/templates/plan-template.md" && ! -f "$skill_dir/templates/plan-template.md" ]]; then
            mkdir -p "$skill_dir/templates"
            cp "iikit-core/templates/plan-template.md" "$skill_dir/templates/plan-template.md"
            echo "  Copied templates/plan-template.md → ${skill_dir}templates/ (script dep)"
        fi
    fi
    if echo "$bash_scripts" | grep -q "^create-new-feature\.sh$"; then
        if [[ -f "iikit-core/templates/spec-template.md" && ! -f "$skill_dir/templates/spec-template.md" ]]; then
            mkdir -p "$skill_dir/templates"
            cp "iikit-core/templates/spec-template.md" "$skill_dir/templates/spec-template.md"
            echo "  Copied templates/spec-template.md → ${skill_dir}templates/ (script dep)"
        fi
    fi
    if echo "$bash_scripts" | grep -q "^update-agent-context\.sh$"; then
        if [[ -f "iikit-core/templates/agent-file-template.md" && ! -f "$skill_dir/templates/agent-file-template.md" ]]; then
            mkdir -p "$skill_dir/templates"
            cp "iikit-core/templates/agent-file-template.md" "$skill_dir/templates/agent-file-template.md"
            echo "  Copied templates/agent-file-template.md → ${skill_dir}templates/ (script dep)"
        fi
    fi

    # Copy dashboard directory when generate-dashboard-safe is present (transitive dep —
    # generate-dashboard-safe.sh looks for ../dashboard/generate-dashboard.js at runtime)
    if echo "$bash_scripts" | grep -q "^generate-dashboard-safe\.sh$"; then
        if [[ -d "iikit-core/scripts/dashboard" ]]; then
            mkdir -p "$skill_dir/scripts/dashboard"
            cp -R iikit-core/scripts/dashboard/* "$skill_dir/scripts/dashboard/"
            echo "  Copied scripts/dashboard/ → ${skill_dir}scripts/dashboard/ (transitive dep)"
        fi
    fi

    # Rewrite SKILL.md: iikit-core/scripts/{bash,powershell}/ → <skill-name>/scripts/{bash,powershell}/
    if sed --version 2>/dev/null | grep -q GNU; then
        sed -i "s|iikit-core/scripts/bash/|$skill_name/scripts/bash/|g" "$skill_md"
        sed -i "s|iikit-core/scripts/powershell/|$skill_name/scripts/powershell/|g" "$skill_md"
    else
        sed -i '' "s|iikit-core/scripts/bash/|$skill_name/scripts/bash/|g" "$skill_md"
        sed -i '' "s|iikit-core/scripts/powershell/|$skill_name/scripts/powershell/|g" "$skill_md"
    fi

    echo "✓ $skill_dir scripts self-contained"
done
echo "✓ Scripts distributed to skills"

# Step 3: Clean up iikit-core — distributed files no longer needed in published tile
rm -rf iikit-core/references
echo "✓ Removed iikit-core/references/ (fully distributed)"

# Remove templates only referenced from SKILL.md (now distributed as local copies)
# Keep templates referenced by scripts: agent-file-template.md, spec-template.md, plan-template.md, premise-template.md
for tmpl in constitution-template.md checklist-template.md tasks-template.md testspec-template.md; do
    rm -f "iikit-core/templates/$tmpl"
done
echo "✓ Removed distributed-only templates from iikit-core/templates/"
