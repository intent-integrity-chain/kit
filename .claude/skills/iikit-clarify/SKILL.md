---
name: iikit-clarify
description: >-
  Resolve ambiguities in any project artifact — auto-detects the most recent artifact (spec, plan, checklist, testify, tasks, or constitution),
  asks targeted questions with option tables, and writes answers back into the artifact's Clarifications section.
  Use when requirements are unclear, a plan has trade-off gaps, checklist thresholds feel wrong, test scenarios are imprecise,
  task dependencies seem off, or constitution principles are vague.
license: MIT
metadata:
  version: "2.5.0"
---

# Intent Integrity Kit Clarify (Generic Utility)

Ask targeted clarification questions to reduce ambiguity in the detected (or user-specified) artifact, then encode answers back into it.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

If the user provides a target argument (e.g., `plan`, `spec`, `checklist`, `testify`, `tasks`, `constitution`), use that artifact instead of auto-detection.

## Constitution Loading

Load constitution per [constitution-loading.md](./references/constitution-loading.md) (soft mode — parse if exists, continue if not).

## Prerequisites Check

1. Run: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-clarify/scripts/bash/check-prerequisites.sh --phase clarify --json`
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-clarify/scripts/powershell/check-prerequisites.ps1 -Phase clarify -Json`
2. Parse JSON. If `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](./references/conversation-guide.md). After user selects, run:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-clarify/scripts/bash/set-active-feature.sh --json <selection>
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-clarify/scripts/powershell/set-active-feature.ps1 -Json <selection>`

   Then re-run the prerequisites check from step 1.
3. Determine the target artifact (see "Target Detection" below).

## Target Detection

If the user provided a target argument, map it:

| Argument | Artifact file |
|----------|--------------|
| `spec` | `{FEATURE_DIR}/spec.md` |
| `plan` | `{FEATURE_DIR}/plan.md` |
| `checklist` | `{FEATURE_DIR}/checklists/*.md` (all files) |
| `testify` | `{FEATURE_DIR}/tests/features/*.feature` (all files) |
| `tasks` | `{FEATURE_DIR}/tasks.md` |
| `constitution` | `{REPO_ROOT}/CONSTITUTION.md` |

If no argument, auto-detect by checking artifacts in reverse phase order. Pick the first that exists:

1. `{FEATURE_DIR}/tasks.md`
2. `{FEATURE_DIR}/tests/features/*.feature`
3. `{FEATURE_DIR}/checklists/*.md`
4. `{FEATURE_DIR}/plan.md`
5. `{FEATURE_DIR}/spec.md`
6. `{REPO_ROOT}/CONSTITUTION.md`

If no clarifiable artifact exists: ERROR with `No artifacts to clarify. Run /iikit-01-specify first or /iikit-00-constitution.`

## Execution Steps

### 1. Scan for Ambiguities

Load the target artifact and perform a structured scan using the taxonomy for that artifact type from [ambiguity-taxonomies.md](./references/ambiguity-taxonomies.md). Mark each area: Clear / Partial / Missing.

### 2. Generate Question Queue

**Constraints**:
- Each answerable with multiple-choice (2-5 options) OR short phrase (<=5 words)
- Identify related artifact items for each question:
  - Spec: FR-xxx, US-x, SC-xxx
  - Plan: section headers or decision IDs
  - Checklist: check item IDs
  - Testify: scenario names
  - Tasks: task IDs (T-xxx)
  - Constitution: principle names or section headers
- Only include questions that materially impact downstream phases
- Balance category coverage, exclude already-answered, favor downstream rework reduction

### 3. Sequential Questioning

Present ONE question at a time.

**For multiple-choice**: follow the options presentation pattern in [conversation-guide.md](./references/conversation-guide.md). Analyze options, state recommendation with reasoning, render options table. User can reply with letter, "yes"/"recommended", or custom text.

**After answer**: validate against constraints, record, move to next.

**Stop when**: all critical ambiguities resolved or user signals done.

### 4. Integration After Each Answer

1. Ensure `## Clarifications` section exists in the target artifact with `### Session YYYY-MM-DD` subheading
2. Append: `- Q: <question> -> A: <answer> [<refs>]`
   - References MUST list every affected item in the artifact
   - If cross-cutting, reference all materially affected items
3. Apply clarification to the appropriate section of the artifact
4. **Save artifact after each integration** to minimize context loss

See [clarification-format.md](references/clarification-format.md) for format details.

### 5. Validation

After each write and final pass:
- One bullet per accepted answer, each ending with `[refs]`
- All referenced IDs exist in the artifact
- No vague placeholders or contradictions remain

### 6. Report

Output: questions asked/answered, target artifact and path, sections touched, traceability summary table (clarification -> referenced items), coverage summary (category -> status), suggested next command.

**Next command logic**: run `check-prerequisites.sh --json status` and use its `next_step` field. This returns the actual next phase based on feature state (which artifacts exist), not what was just clarified. Clarify can run at any point — the next step depends on where the feature is, not where clarify was invoked.

## Behavior Rules

- No meaningful ambiguities found: "No critical ambiguities detected." and suggest proceeding
- Continue until all critical ambiguities are resolved
- Avoid speculative tech stack questions unless absence blocks functional clarity
- Respect early termination signals ("stop", "done", "proceed")
- For non-spec artifacts, adapt reference format to the artifact's native ID scheme

## Next Steps

Run: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-clarify/scripts/bash/next-step.sh --phase clarify --json`
Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-clarify/scripts/powershell/next-step.ps1 -Phase clarify -Json`

Parse the JSON and present:
1. If `clear_after` is true: suggest `/clear` before proceeding (always true for clarify — Q&A sessions consume significant context)
2. Present `next_step` as the primary recommendation
3. If `alt_steps` non-empty: list as alternatives
4. Look up `model_tier` in [model-recommendations.md](./references/model-recommendations.md) — if tier differs from current, add a `Tip:` with the agent-specific switch command. Check expiration date; refresh via web search if expired.
5. Append dashboard link

Format:
```
Clarification complete!
Next: /clear → <next_step>
[- <alt_step> — <reason>]
[Tip: <model suggestion>]
- Dashboard: file://$(pwd)/.specify/dashboard.html (resolve the path)
```
