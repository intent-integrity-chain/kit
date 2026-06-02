---
name: iikit-02-plan
description: >-
  Generate a technical design document from a feature spec — selects frameworks, defines data models, produces API contracts, and creates a dependency-ordered implementation strategy.
  Use when planning how to build a feature, writing a technical design doc, choosing libraries, defining database schemas, or setting up Tessl tiles for runtime library knowledge.
license: MIT
metadata:
  version: "1.6.4"
---

# Intent Integrity Kit Plan

Process steps in order. Do not skip ahead.

Generate design artifacts from the feature specification using the plan template.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Constitution Loading

Load constitution per [constitution-loading.md](../iikit-core/references/constitution-loading.md) (enforcement mode — extract rules, declare hard gate, halt on violations).

## Prerequisites Check

1. Run prerequisites check:
   ```bash
   bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase 02 --json
   ```
   Windows: `pwsh .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase 02 -Json`

2. Parse JSON for `FEATURE_SPEC`, `IMPL_PLAN`, `FEATURE_DIR`, `BRANCH`. If missing spec.md: ERROR.
3. If JSON contains `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). After user selects, run:
   ```bash
   bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selection>
   ```
   Windows: `pwsh .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selection>`

   Then re-run the prerequisites check from step 1.

## Spec Quality Gate

**MANDATORY on every run** (including re-runs when plan.md already exists) — you MUST complete this gate and report the results before proceeding to the Execution Flow. Do NOT skip this section.

Validate spec.md and output the results:

1. **Requirements**: count FR-XXX patterns (ERROR if 0, WARNING if <3)
2. **Measurable criteria**: scan for numeric values, percentages, time measurements (WARNING if none found — report which SC-XXX lack measurable values)
3. **Unresolved clarifications**: search for `[NEEDS CLARIFICATION]` — ask whether to proceed with assumptions
4. **User story coverage**: verify each story has acceptance scenarios
5. **Cross-references**: check for orphan requirements not linked to stories

**Output the quality score** using this format (from [formatting-guide.md](../iikit-core/references/formatting-guide.md)):
```
Spec Quality: X/10
  Requirements: N FR-XXX found [✓|⚠|✗]
  Measurable criteria: N of M SC-XXX have numeric targets [✓|⚠|✗]
  Clarifications: N unresolved [✓|⚠|✗]
  Story coverage: N of M stories have scenarios [✓|⚠|✗]
  Cross-references: N orphan requirements [✓|⚠|✗]
```

If score < 6: recommend `/iikit-clarify` first.

## Step 1 — Fill Technical Context

Using the plan template, define: Language/Version, Primary Dependencies, Storage, Testing, Target Platform, Project Type, Performance Goals, Constraints, Scale/Scope. Mark unknowns as "NEEDS CLARIFICATION".

When Tessl eval results are available for candidate technologies, include eval scores in the decision rationale in research.md. Higher eval scores indicate better-validated tiles and should factor into technology selection when choosing between alternatives.

## Step 2 — Tessl Tile Discovery

If Tessl is installed, discover and install tiles for all technologies. See [tessl-tile-discovery.md](references/tessl-tile-discovery.md) for the full procedure.

## Step 3 — Research & Resolve Unknowns

For each NEEDS CLARIFICATION item and dependency: research, document findings in `research.md` with decision, rationale, and alternatives considered. Include Tessl Tiles section if applicable.

## Step 4 — Design & Contracts

**Prerequisites**: research.md complete

1. Extract entities from spec -> `data-model.md` (fields, relationships, validation, state transitions)
2. Generate API contracts from functional requirements -> `contracts/`
3. Create `quickstart.md` with test scenarios
4. Update agent context:
   ```bash
   bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/update-agent-context.sh claude
   ```
   Windows: `pwsh .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/update-agent-context.ps1 -AgentType claude`

## Step 5 — Update context.json with Dashboard Data

**MANDATORY** — you MUST update `.specify/context.json` after the plan is complete. Use `jq` to merge into the existing file (create if missing). Do NOT overwrite existing fields.

```bash
CONTEXT_FILE=".specify/context.json"
[[ -f "$CONTEXT_FILE" ]] || echo '{}' > "$CONTEXT_FILE"
```

**Architecture Node Classifications:** If plan.md contains an architecture diagram, classify every named component as one of `client`, `server`, `storage`, or `external` and write the map to `planview.nodeClassifications`:

```bash
jq --argjson nodes '{
  "Browser SPA": "client",
  "API Gateway": "server",
  "PostgreSQL": "storage",
  "Stripe API": "external"
}' '.planview.nodeClassifications = $nodes' "$CONTEXT_FILE" > "$CONTEXT_FILE.tmp" && mv "$CONTEXT_FILE.tmp" "$CONTEXT_FILE"
```

Classification rules: **client** = initiates requests | **server** = processes requests | **storage** = persists data | **external** = outside project boundary

**Tessl Eval Scores:** If Tessl tiles were installed in step 2, write eval scores to `planview.evalScores`:

```bash
jq --argjson evals '{
  "workspace/tile-name": {"score": 85, "pct": 85, "scenarios": 3, "scored_at": "2026-01-15T10:00:00Z"}
}' '.planview.evalScores = $evals' "$CONTEXT_FILE" > "$CONTEXT_FILE.tmp" && mv "$CONTEXT_FILE.tmp" "$CONTEXT_FILE"
```

## Step 6 — Constitution Check (Post-Design)

Re-validate all technical decisions against constitutional principles. On violation: STOP, state violation, suggest compliant alternative.

## Step 7 — Phase Separation Validation

Scan plan for governance content per [phase-separation-rules.md](../iikit-core/references/phase-separation-rules.md) (Plan section). Auto-fix by replacing with constitution references, re-validate.

## Output Validation

Before writing any artifact: review against each constitutional principle. On violation: STOP with explanation and alternative.

## Report

Output: branch name, plan path, generated artifacts (research.md, data-model.md, contracts/*, quickstart.md), agent file update status, Tessl integration status (tiles installed, skills available, technologies without tiles, eval results saved), dashboard pre-computed data status (node classifications written, eval scores written).

## Semantic Diff on Re-run

**On re-runs (plan.md already exists)**, after completing the Spec Quality Gate and Execution Flow above, you MUST compare the old and new plan and output a semantic diff. Use this exact format:

```
+-----------------------------------------------------+
|  SEMANTIC DIFF: plan.md                              |
+-----------------------------------------------------+
|  Tech Stack:                                         |
|    + Added: [new items]                              |
|    ~ Changed: [modified items]                       |
|    - Removed: [deleted items]                        |
|  Architecture:                                       |
|    + Added: [new components]                         |
|    ~ Changed: [modified components]                  |
|  Dependencies:                                       |
|    + Added: [new deps]                               |
|    - Removed: [old deps]                             |
+-----------------------------------------------------+
|  DOWNSTREAM IMPACT                                   |
|    ⚠ tasks.md may need regeneration                  |
|    ⚠ [other affected artifacts]                      |
+-----------------------------------------------------+
```

Flag breaking changes that would invalidate existing tasks or test specs.

## Commit, Dashboard & Next Steps

Run post-phase to commit, refresh dashboard, and compute next step in a single call:

```bash
bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/post-phase.sh --phase 02 --commit-files "specs/*/plan.md,specs/*/research.md,specs/*/data-model.md,specs/*/quickstart.md,specs/*/contracts/,.specify/context.json" --commit-msg "plan: <feature-short-name> technical design"
```
Windows: `pwsh .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/post-phase.ps1 -Phase 02 -CommitFiles "specs/*/plan.md,specs/*/research.md,specs/*/data-model.md,specs/*/quickstart.md,specs/*/contracts/,.specify/context.json" -CommitMsg "plan: <feature-short-name> technical design"`

Parse `next_step` from JSON. Present per [model-recommendations.md](../iikit-core/references/model-recommendations.md):
```
Plan complete!
Next: [/clear → ] <next_step> (model: <tier>)
[- <alt_step> — <reason> (model: <tier>)]
- Dashboard: file://$(pwd)/.specify/dashboard.html
```
