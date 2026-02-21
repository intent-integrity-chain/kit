---
name: iikit-03-plan
description: >-
  Generate a technical design document from a feature spec — selects frameworks, defines data models, produces API contracts, and creates a dependency-ordered implementation strategy.
  Use when planning how to build a feature, writing a technical design doc, choosing libraries, defining database schemas, or setting up Tessl tiles for runtime library knowledge.
license: MIT
metadata:
  version: "1.6.4"
---

# Intent Integrity Kit Plan

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
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase 03 --json
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase 03 -Json`

2. Parse JSON for `FEATURE_SPEC`, `IMPL_PLAN`, `FEATURE_DIR`, `BRANCH`. If missing spec.md: ERROR.
3. If JSON contains `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). After user selects, run:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selection>
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selection>`

   Then re-run the prerequisites check from step 1.

## Spec Quality Gate

Before planning, validate spec.md:

1. **Requirements**: count FR-XXX patterns (ERROR if 0, WARNING if <3)
2. **Measurable criteria**: scan for numeric values, percentages, time measurements (WARNING if none)
3. **Unresolved clarifications**: search for `[NEEDS CLARIFICATION]` — ask whether to proceed with assumptions
4. **User story coverage**: verify each story has acceptance scenarios
5. **Cross-references**: check for orphan requirements not linked to stories

Report quality score per [formatting-guide.md](../iikit-core/references/formatting-guide.md) (Spec Quality section). If score < 6: recommend `/iikit-02-clarify` first.

## Execution Flow

### 1. Fill Technical Context

Using the plan template, define: Language/Version, Primary Dependencies, Storage, Testing, Target Platform, Project Type, Performance Goals, Constraints, Scale/Scope. Mark unknowns as "NEEDS CLARIFICATION".

When Tessl eval results are available for candidate technologies, include eval scores in the decision rationale in research.md. Higher eval scores indicate better-validated tiles and should factor into technology selection when choosing between alternatives.

### 2. Tessl Tile Discovery

If Tessl is installed, discover and install tiles for all technologies. See [tessl-tile-discovery.md](references/tessl-tile-discovery.md) for the full procedure.

### 3. Research & Resolve Unknowns

For each NEEDS CLARIFICATION item and dependency: research, document findings in `research.md` with decision, rationale, and alternatives considered. Include Tessl Tiles section if applicable.

### 4. Design & Contracts

**Prerequisites**: research.md complete

1. Extract entities from spec -> `data-model.md` (fields, relationships, validation, state transitions)
2. Generate API contracts from functional requirements -> `contracts/`
3. Create `quickstart.md` with test scenarios
4. Update agent context:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/update-agent-context.sh claude
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/update-agent-context.ps1 -AgentType claude`

### 5. Pre-compute Dashboard Data

After the plan is complete, write pre-computed data to `.specify/context.json` for static dashboard generation. Use `jq` to merge into the existing file (create if missing).

#### 5a. Architecture Node Classifications

If plan.md contains an architecture diagram (ASCII box-drawing), classify each named component as one of: `client`, `server`, `storage`, `external`.

Write to `.specify/context.json` under `planview.nodeClassifications`:

```bash
# Read existing or start fresh
CONTEXT_FILE=".specify/context.json"
[[ -f "$CONTEXT_FILE" ]] || echo '{}' > "$CONTEXT_FILE"

# Merge node classifications (replace example with actual nodes from the plan diagram)
jq --argjson nodes '{
  "Browser SPA": "client",
  "API Gateway": "server",
  "PostgreSQL": "storage",
  "Stripe API": "external"
}' '.planview.nodeClassifications = $nodes' "$CONTEXT_FILE" > "$CONTEXT_FILE.tmp" && mv "$CONTEXT_FILE.tmp" "$CONTEXT_FILE"
```

Classification rules:
- **client**: browsers, CLIs, mobile apps, desktop apps — anything that initiates requests
- **server**: APIs, gateways, workers, middleware, backend services — anything that processes requests
- **storage**: databases, caches, queues, file stores, object storage — anything that persists data
- **external**: third-party APIs, SaaS services, payment providers — anything outside the project boundary

If no architecture diagram exists in the plan, skip this step.

#### 5b. Tessl Eval Scores

If Tessl tiles were installed in step 2, collect eval scores from the `fetch-tile-evals.sh` outputs and write a summary to `context.json`:

```bash
# Merge eval scores (replace example with actual tile names and scores from step 2)
jq --argjson evals '{
  "workspace/tile-name": {"score": 85, "pct": 85, "scenarios": 3, "scored_at": "2026-01-15T10:00:00Z"}
}' '.planview.evalScores = $evals' "$CONTEXT_FILE" > "$CONTEXT_FILE.tmp" && mv "$CONTEXT_FILE.tmp" "$CONTEXT_FILE"
```

Use the JSON output from each `fetch-tile-evals.sh --json` call (already run in step 2 via tessl-tile-discovery.md). Extract `score`, `pct`, `scenarios`, and `scored_at` fields for each tile.

If no Tessl tiles were installed, skip this step.

### 6. Constitution Check (Post-Design)

Re-validate all technical decisions against constitutional principles. On violation: STOP, state violation, suggest compliant alternative.

### 7. Phase Separation Validation

Scan plan for governance content per [phase-separation-rules.md](../iikit-core/references/phase-separation-rules.md) (Plan section). Auto-fix by replacing with constitution references, re-validate.

## Output Validation

Before writing any artifact: review against each constitutional principle. On violation: STOP with explanation and alternative.

## Report

Output: branch name, plan path, generated artifacts (research.md, data-model.md, contracts/*, quickstart.md), agent file update status, Tessl integration status (tiles installed, skills available, technologies without tiles, eval results saved), dashboard pre-computed data status (node classifications written, eval scores written).

## Semantic Diff on Re-run

If plan.md exists: compare tech stack, architecture, dependencies. Show diff per [formatting-guide.md](../iikit-core/references/formatting-guide.md) (Semantic Diff section) with downstream impact. Flag breaking changes.

## Next Steps

You MUST read [model-recommendations.md](../iikit-core/references/model-recommendations.md), check the expiration date (refresh via web search if expired), detect the agent via env vars, and include a model switch tip in the output below if the next phase needs a different model tier.

```
Plan complete! Next steps:
- /iikit-04-checklist - (Recommended) Generate quality checklists
- /iikit-05-testify - (REQUIRED by constitution) Generate test specifications [if TDD mandatory]
- /iikit-05-testify - (Optional) Generate test specifications for TDD [if TDD not mandatory]
- /iikit-06-tasks - Generate task breakdown from plan
Tip: <model switch suggestion if tier mismatch, omit if already on the right model>
```
