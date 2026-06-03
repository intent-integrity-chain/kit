---
name: iikit-03-checklist
description: >-
  Generate quality checklists that validate requirements completeness, clarity, and consistency — produces scored checklist items linked to specific spec sections (FR-XXX, SC-XXX).
  Use when reviewing a spec for gaps, doing a requirements review, verifying PRD quality, auditing user stories and acceptance criteria, or gating before implementation.
license: MIT
metadata:
  version: "1.6.4"
---

# Intent Integrity Kit Checklist

Process steps in order. Do not skip ahead.

Generate checklists that validate REQUIREMENTS quality, not implementation.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Constitution Loading

Load constitution per [constitution-loading.md](../iikit-core/references/constitution-loading.md) (basic mode).

## Prerequisites Check

1. Run: `bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase 03 --json`
   Windows: `pwsh .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase 03 -Json`
2. Parse JSON for `FEATURE_DIR` and `AVAILABLE_DOCS`.
3. If JSON contains `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). After user selects, run:
   ```bash
   bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selection>
   ```
   Windows: `pwsh .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selection>`

   Then re-run the prerequisites check (item 1 of this section).

## Step 1 — Clarify Intent

Derive up to THREE contextual questions (skip if unambiguous from `$ARGUMENTS`):
- Scope: include integration touchpoints?
- Risk: which areas need mandatory gating?
- Depth: lightweight sanity list or formal release gate?
- Audience: author-only or peer PR review?

Proceed immediately to Step 2.



## Step 2 — Load Feature Context

Read from FEATURE_DIR: `spec.md` (required), `plan.md` (optional), `tasks.md` (optional).

Proceed immediately to Step 3.



## Step 3 — Generate Checklist

**Starting point**: `FEATURE_DIR/checklists/requirements.md` already exists (created by `/iikit-01-specify`). Review it, extend it with additional items, and resolve gaps. Do NOT create a duplicate — work with the existing file.

**Additional domain checklists** (optional): if the spec has distinct domains that warrant separate review (e.g., security, performance, accessibility), create additional files as `FEATURE_DIR/checklists/[domain].md`. These supplement `requirements.md`, not replace it.

**Item structure**: question format about requirement quality, with quality dimension tag and spec reference.

- ✓ "Are visual hierarchy requirements defined with measurable criteria?" [Clarity, Spec SFR-1]
- ✗ "Verify the button clicks correctly" — tests implementation, not requirements

**Categories**: Requirement Completeness, Clarity, Consistency, Acceptance Criteria Quality, Scenario Coverage, SC-XXX Test Coverage, Edge Case Coverage, Non-Functional Requirements, Dependencies & Assumptions.

**Traceability**: >=80% of items must reference spec sections or use markers: `[Gap]`, `[Ambiguity]`, `[Conflict]`, `[Assumption]`.

See [checklist-examples.md](references/checklist-examples.md) for correct/wrong examples and required patterns.

Use [checklist-template.md](../iikit-core/templates/checklist-template.md) for format structure.

Proceed immediately to Step 4.



## Step 4 — Gap Resolution (Interactive)

For each `[Gap]` item: follow the gap resolution pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). Present missing requirement, explain risk, offer options. On resolution: update spec.md and check item off. Skip if `--no-interactive` or no gaps.

Proceed immediately to Step 5.



## Step 5 — Remaining Item Validation

After gap resolution, validate ALL unchecked `[ ]` items against spec/plan/constitution:
- If covered: check off with justification
- If genuine gap: convert to `[Gap]` and resolve or defer

Continue until all items are `[x]` or explicitly deferred.

**IMPORTANT**: Checklists are optional — not creating one is fine. But once created, they MUST reach 100% before the skill reports success.

Proceed immediately to Step 6.



## Step 6 — Report

Output: checklist path, item counts (total/checked/deferred), gap resolution summary, completion percentage.

Finish here.



## Record Phase Completion

Write a timestamp to `.specify/context.json` so the dashboard knows the checklist phase was run (not just that requirements.md exists from specify):

```bash
CONTEXT_FILE=".specify/context.json"
[[ -f "$CONTEXT_FILE" ]] || echo '{}' > "$CONTEXT_FILE"
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.checklist_reviewed_at = $ts' "$CONTEXT_FILE" > "$CONTEXT_FILE.tmp" && mv "$CONTEXT_FILE.tmp" "$CONTEXT_FILE"
```

## Commit, Dashboard & Next Steps

Run post-phase to commit, refresh dashboard, and compute next step in a single call:

```bash
bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/post-phase.sh --phase 03 --commit-files "specs/*/checklists/,.specify/context.json" --commit-msg "checklist: <feature-short-name> requirements review"
```
Windows: `pwsh .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/post-phase.ps1 -Phase 03 -CommitFiles "specs/*/checklists/,.specify/context.json" -CommitMsg "checklist: <feature-short-name> requirements review"`

Parse `next_step` from JSON. Present per [model-recommendations.md](../iikit-core/references/model-recommendations.md):
```
Checklist complete!
Next: [/clear → ] <next_step> (model: <tier>)
[- <alt_step> — <reason> (model: <tier>)]
- Dashboard: file://$(pwd)/.specify/dashboard.html
```

If deferred items remain, warn that downstream skills will flag incomplete checklists.
