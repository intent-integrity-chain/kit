---
name: iikit-04-checklist
description: >-
  Generate quality checklists that validate requirements completeness, clarity, and consistency — produces scored checklist items linked to specific spec sections (FR-XXX, SC-XXX).
  Use when reviewing a spec for gaps, doing a requirements review, verifying PRD quality, auditing user stories and acceptance criteria, or gating before implementation.
license: MIT
metadata:
  version: "1.6.4"
---

# Intent Integrity Kit Checklist

Generate "Unit Tests for English" — checklists that validate REQUIREMENTS quality, not implementation.

## Core Principle

Every checklist item evaluates the **requirements themselves** for completeness, clarity, consistency, measurability, and coverage. Items MUST NOT test implementation behavior.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Constitution Loading

Load constitution per [constitution-loading.md](../iikit-core/references/constitution-loading.md) (basic mode).

## Prerequisites Check

1. Run: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase 04 --json`
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase 04 -Json`
2. Parse JSON for `FEATURE_DIR` and `AVAILABLE_DOCS`.
3. If JSON contains `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). After user selects, run:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selection>
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selection>`

   Then re-run the prerequisites check from step 1.

## Execution Steps

### 1. Clarify Intent

Derive up to THREE contextual questions (skip if unambiguous from `$ARGUMENTS`):
- Scope: include integration touchpoints?
- Risk: which areas need mandatory gating?
- Depth: lightweight sanity list or formal release gate?
- Audience: author-only or peer PR review?

### 2. Load Feature Context

Read from FEATURE_DIR: `spec.md` (required), `plan.md` (optional), `tasks.md` (optional).

### 3. Generate Checklist

Create `FEATURE_DIR/checklists/[domain].md`.

**Item structure**: question format about requirement quality, with quality dimension tag and spec reference.

Correct: "Are visual hierarchy requirements defined with measurable criteria?" [Clarity, Spec SFR-1]
Wrong: "Verify the button clicks correctly" (this tests implementation)

**Categories**: Requirement Completeness, Clarity, Consistency, Acceptance Criteria Quality, Scenario Coverage, Edge Case Coverage, Non-Functional Requirements, Dependencies & Assumptions.

**Traceability**: >=80% of items must reference spec sections or use markers: `[Gap]`, `[Ambiguity]`, `[Conflict]`, `[Assumption]`.

See [checklist-examples.md](references/checklist-examples.md) for correct/wrong examples and required patterns.

Use [checklist-template.md](../iikit-core/templates/checklist-template.md) for format structure.

### 4. Gap Resolution (Interactive)

For each `[Gap]` item: follow the gap resolution pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). Present missing requirement, explain risk, offer options. On resolution: update spec.md and check item off. Skip if `--no-interactive` or no gaps.

### 5. Remaining Item Validation

After gap resolution, validate ALL unchecked `[ ]` items against spec/plan/constitution:
- If covered: check off with justification
- If genuine gap: convert to `[Gap]` and resolve or defer

Continue until all items are `[x]` or explicitly deferred.

**IMPORTANT**: Checklists are optional — not creating one is fine. But once created, they MUST reach 100% before the skill reports success.

### 6. Report

Output: checklist path, item counts (total/checked/deferred), gap resolution summary, completion percentage.

## Next Steps

Suggest the user run `/clear` before proceeding — the interactive gap resolution consumed significant context. State is preserved in checklist files and `.specify/context.json`.

```
Checklist complete! (100%)
Next steps:
- /iikit-05-testify - (Optional) Generate test specifications for TDD
- /iikit-06-tasks - Generate task breakdown from plan
```

If deferred items remain, warn that downstream skills will flag incomplete checklists.
