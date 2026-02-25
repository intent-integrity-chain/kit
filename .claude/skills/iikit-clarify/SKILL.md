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

Load constitution per [constitution-loading.md](../iikit-core/references/constitution-loading.md) (soft mode — parse if exists, continue if not).

## Prerequisites Check

1. Run: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase clarify --json`
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase clarify -Json`
2. Parse JSON. If `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). After user selects, run:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selection>
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selection>`

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

Load the target artifact and perform a structured scan using the taxonomy for that artifact type. Mark each area: Clear / Partial / Missing.

**Spec** (`spec.md`):
- Functional Scope: core goals, out-of-scope declarations, user roles
- Domain & Data Model: entities, identity rules, state transitions, scale
- Interaction & UX: critical journeys, error/empty/loading states, accessibility
- Non-Functional: performance, scalability, reliability, observability, security, compliance
- Integrations: external APIs, data formats, protocol assumptions
- Edge Cases: negative scenarios, rate limiting, conflict resolution
- Constraints: technical constraints, rejected alternatives
- Terminology: canonical terms, deprecated synonyms
- Completion Signals: acceptance criteria testability, measurable DoD

**Plan** (`plan.md`):
- Framework Choice: rationale, alternatives considered, migration risk
- Architecture: component boundaries, data flow, failure modes
- Trade-offs: performance vs. complexity, build vs. buy, consistency vs. availability
- Scalability: bottleneck awareness, horizontal/vertical limits
- Dependency Risks: version pinning, license compatibility, maintenance status
- Integration Points: API contracts, protocol assumptions, error propagation

**Checklist** (`checklists/*.md`):
- Threshold Appropriateness: are numeric thresholds realistic and measurable?
- Missing Checks: gaps in coverage for the spec requirements
- False Positives: checks that would pass for wrong reasons
- Prioritization: are critical checks distinguishable from nice-to-haves?

**Testify** (`features/*.feature`):
- Scenario Precision: are Given/When/Then steps unambiguous?
- Missing Paths: unhappy paths, edge cases, boundary conditions
- Given/When/Then Completeness: missing preconditions, unclear actions, vague expectations
- Data Variety: are test data examples representative?

**Tasks** (`tasks.md`):
- Dependency Correctness: are blockers accurate? circular dependencies?
- Ordering: does the sequence make implementation sense?
- Scope: are tasks appropriately sized? any too large or too small?
- Parallelization: are parallel markers (`[P]`) accurate?

**Constitution** (`CONSTITUTION.md`):
- Principle Clarity: are principles actionable or vague?
- Threshold Specificity: are numeric gates defined (e.g., "high coverage" → what number)?
- Conflict Resolution: do any principles contradict each other?
- Completeness: are there governance areas not covered?
- Enforcement Gaps: which principles lack verification mechanisms?

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

**For multiple-choice**: follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). Analyze options, state recommendation with reasoning, render options table. User can reply with letter, "yes"/"recommended", or custom text.

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

**Next command logic**: suggest the next phase command based on the artifact clarified:
- After spec clarification: `/iikit-02-plan`
- After plan clarification: `/iikit-03-checklist`
- After checklist clarification: `/iikit-04-testify` or `/iikit-05-tasks`
- After testify clarification: `/iikit-05-tasks`
- After tasks clarification: `/iikit-06-analyze`
- After constitution clarification: `/iikit-01-specify <description>`

## Behavior Rules

- No meaningful ambiguities found: "No critical ambiguities detected." and suggest proceeding
- Continue until all critical ambiguities are resolved
- Avoid speculative tech stack questions unless absence blocks functional clarity
- Respect early termination signals ("stop", "done", "proceed")
- For non-spec artifacts, adapt reference format to the artifact's native ID scheme

## Next Steps

You MUST read [model-recommendations.md](../iikit-core/references/model-recommendations.md), check the expiration date (refresh via web search if expired), detect the agent via env vars, and include a model switch tip in the output below if the next phase needs a different model tier.

```
Clarification complete! Next: /clear then <next_command>
(Q&A consumed significant context — /clear before next phase is recommended)
Tip: <model switch suggestion if tier mismatch, omit if already on the right model>
- Dashboard: file://$(pwd)/.specify/dashboard.html (resolve the path)
```
