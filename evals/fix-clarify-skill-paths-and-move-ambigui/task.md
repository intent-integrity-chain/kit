# Fix Clarify Skill Paths and Move Ambiguity Taxonomy to Shared Core

## Problem/Feature Description

The `iikit-clarify` skill's `SKILL.md` file appears to have incorrect path references. Right now it references shared documents like `constitution-loading.md`, `conversation-guide.md`, and `model-recommendations.md` using local paths (`./references/`). But those files don't actually exist in `iikit-clarify/references/` — they live in the shared `iikit-core/references/` folder. Other skills like `iikit-01-specify` and `iikit-02-plan` already use the correct `../iikit-core/references/` pattern. The clarify skill also invokes shell scripts using `iikit-clarify/scripts/` paths for things like `check-prerequisites.sh`, `set-active-feature.sh`, and `next-step.sh` — but those scripts are actually part of the shared `iikit-core` skill.

On a related note, the ambiguity taxonomy document (`references/ambiguity-taxonomies.md`) currently lives inside `iikit-clarify/references/`. This file defines scanning categories for all artifact types (specs, plans, checklists, Gherkin features, tasks, and constitutions) — it's not really clarify-specific. It would make more sense for it to live in `iikit-core/references/` as a shared reference, since other skills might benefit from it too. Can you move it there and update the reference in SKILL.md?

Also, I noticed the `iikit-core/templates/constitution-template.md` is missing Roman numeral numbering on the principle headings. The comments show examples like `I. Library-First`, `II. CLI Interface`, `III. Test-First`, etc., but the actual heading placeholders just say `[PRINCIPLE_1_NAME]` without the Roman numeral prefix. Can you fix the template headings to include Roman numeral prefixes?

Finally, please bump the version in `tiles/intent-integrity-kit/tile.json` to reflect these fixes.

## Expected Behavior

- The `iikit-clarify/SKILL.md` file should reference shared documentation using `../iikit-core/references/` paths, matching the pattern used by all other iikit-* skills.
- Script paths in `iikit-clarify/SKILL.md` (for `check-prerequisites`, `set-active-feature`, `next-step`) should point to `iikit-core/scripts/` rather than `iikit-clarify/scripts/`.
- The `ambiguity-taxonomies.md` file defining per-artifact ambiguity scanning categories should exist at `iikit-core/references/ambiguity-taxonomies.md`.
- The reference to this file in `iikit-clarify/SKILL.md` should point to the new shared location.
- The `constitution-template.md` principle headings should use Roman numeral prefixes (e.g., `### I. [PRINCIPLE_1_NAME]`).

## Acceptance Criteria

- `iikit-clarify/SKILL.md` has no remaining references to `./references/` for shared documents — all shared resource links use `../iikit-core/references/`.
- Script invocations in `iikit-clarify/SKILL.md` use `iikit-core` as the script source, not `iikit-clarify`.
- `iikit-core/references/ambiguity-taxonomies.md` exists with the per-artifact scanning taxonomy content.
- `iikit-core/templates/constitution-template.md` principle headings include Roman numeral numbering (I., II., III., IV., V.).
