---
name: iikit-02-clarify
description: >-
  Resolve ambiguities in a feature specification — identifies underspecified areas, asks up to 5 targeted questions with option tables, and updates spec.md with answers linked to affected requirements (FR-XXX, SC-XXX).
  Use when requirements are unclear, the spec has gaps, details are missing, user stories need refinement, or you want to tighten acceptance criteria before planning.
license: MIT
---

# Intent Integrity Kit Clarify

Ask up to 5 targeted clarification questions to reduce ambiguity in the active feature spec, then encode answers back into the spec.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Constitution Loading

Load constitution per [constitution-loading.md](../iikit-core/references/constitution-loading.md) (soft mode — parse if exists, continue if not).

## Prerequisites Check

1. Run: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase 02 --json`
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase 02 -Json`
2. Parse JSON for `FEATURE_DIR` and `FEATURE_SPEC`. If missing: ERROR with `Run: /iikit-01-specify`.
3. If JSON contains `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). After user selects, run:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selection>
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selection>`

   Then re-run the prerequisites check from step 1.

## Execution Steps

### 1. Scan for Ambiguities

Load spec and perform structured scan using this taxonomy. Mark each: Clear / Partial / Missing.

- **Functional Scope**: core goals, out-of-scope declarations, user roles
- **Domain & Data Model**: entities, identity rules, state transitions, scale
- **Interaction & UX**: critical journeys, error/empty/loading states, accessibility
- **Non-Functional**: performance, scalability, reliability, observability, security, compliance
- **Integrations**: external APIs, data formats, protocol assumptions
- **Edge Cases**: negative scenarios, rate limiting, conflict resolution
- **Constraints**: technical constraints, rejected alternatives
- **Terminology**: canonical terms, deprecated synonyms
- **Completion Signals**: acceptance criteria testability, measurable DoD

### 2. Generate Question Queue (max 5)

**Constraints**:
- Each answerable with multiple-choice (2-5 options) OR short phrase (<=5 words)
- Identify related spec items (FR-xxx, US-x, SC-xxx) for each question
- Only include questions that materially impact architecture, data, tasks, tests, UX, or compliance
- Balance category coverage, exclude already-answered, favor downstream rework reduction

### 3. Sequential Questioning

Present ONE question at a time.

**For multiple-choice**: follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). Analyze options, state recommendation with reasoning, render options table. User can reply with letter, "yes"/"recommended", or custom text.

**After answer**: validate against constraints, record, move to next.

**Stop when**: all critical ambiguities resolved, user signals done, or 5 questions asked.

### 4. Integration After Each Answer

1. Ensure `## Clarifications` section exists in spec with `### Session YYYY-MM-DD` subheading
2. Append: `- Q: <question> -> A: <answer> [FR-001, US-2]`
   - References MUST list every affected spec item
   - If cross-cutting, reference all materially affected items
3. Apply clarification to appropriate spec section (functional -> Requirements, data -> Data Model, etc.)
4. **Save spec after each integration** to minimize context loss

See [clarification-format.md](references/clarification-format.md) for format details.

### 5. Validation

After each write and final pass:
- One bullet per accepted answer, each ending with `[refs]`
- All referenced IDs exist in spec
- Total questions <= 5
- No vague placeholders or contradictions remain

### 6. Report

Output: questions asked/answered, path to updated spec, sections touched, traceability summary table (clarification -> referenced items), coverage summary (category -> status), suggested next command (`/iikit-03-plan`).

## Behavior Rules

- No meaningful ambiguities found: "No critical ambiguities detected." and suggest proceeding
- Never exceed 5 questions
- Avoid speculative tech stack questions unless absence blocks functional clarity
- Respect early termination signals ("stop", "done", "proceed")

## Next Steps

Suggest the user run `/clear` before proceeding — the interactive Q&A session consumed significant context, and planning benefits from a fresh context window. State is preserved in spec.md and `.specify/context.json`.

Run `/iikit-03-plan` to create the technical implementation plan.
