# Reduce Token Bloat in the Clarify Skill

## Problem/Feature Description

The `iikit-clarify` SKILL.md file has grown quite large and is consuming a lot of tokens every time it's loaded. A big chunk of its size comes from the detailed per-artifact ambiguity taxonomy tables that list what to scan for in specs, plans, checklists, feature files, tasks, and constitutions.

The skill itself already uses a pattern of linking to reference files for other pieces of content (like conversation guides and model recommendations). We should use the same approach here to slim down the main skill file without losing the taxonomy content — it should stay accessible, just not inline.

## Expected Behavior

The taxonomy categories for each artifact type (spec, plan, checklist, testify, tasks, constitution) should be extracted from SKILL.md into a dedicated reference file under the skill's `references/` folder. The main SKILL.md should replace the inline taxonomy block with a single link pointing to this new reference file. The clarify skill should work exactly as before, with the taxonomy still reachable via the reference link.

Additionally, any cross-skill path references in the clarify SKILL.md that currently point to `iikit-core` should be corrected to point locally within `iikit-clarify` where the actual resources live.

## Acceptance Criteria

- The main SKILL.md is significantly shorter — the inline taxonomy block is gone
- A new reference file under `iikit-clarify/references/` contains all the per-artifact ambiguity scanning categories
- SKILL.md's scan step points to the new reference file via a relative link
- Internal paths (scripts, reference links) in SKILL.md correctly point to `iikit-clarify` rather than `iikit-core`
