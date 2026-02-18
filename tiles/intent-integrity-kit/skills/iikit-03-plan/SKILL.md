---
name: iikit-03-plan
description: >-
  Create technical implementation plan from feature specification.
  Use when choosing tech stack, designing architecture, planning implementation approach, or setting up Tessl tiles for a feature.
license: MIT
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

1. Run setup script:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/setup-plan.sh --json
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/setup-plan.ps1 -Json`

2. Parse JSON for `FEATURE_SPEC`, `IMPL_PLAN`, `SPECS_DIR`, `BRANCH`. If missing spec.md: ERROR.
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

### 5. Constitution Check (Post-Design)

Re-validate all technical decisions against constitutional principles. On violation: STOP, state violation, suggest compliant alternative.

### 6. Phase Separation Validation

Scan plan for governance content per [phase-separation-rules.md](../iikit-core/references/phase-separation-rules.md) (Plan section). Auto-fix by replacing with constitution references, re-validate.

## Output Validation

Before writing any artifact: review against each constitutional principle. On violation: STOP with explanation and alternative.

## Report

Output: branch name, plan path, generated artifacts (research.md, data-model.md, contracts/*, quickstart.md), agent file update status, Tessl integration status (tiles installed, skills available, technologies without tiles, eval results saved).

## Semantic Diff on Re-run

If plan.md exists: compare tech stack, architecture, dependencies. Show diff per [formatting-guide.md](../iikit-core/references/formatting-guide.md) (Semantic Diff section) with downstream impact. Flag breaking changes.

## Next Steps

```
Plan complete! Next steps:
- /iikit-04-checklist - (Recommended) Generate quality checklists
- /iikit-05-testify - (REQUIRED by constitution) Generate test specifications [if TDD mandatory]
- /iikit-05-testify - (Optional) Generate test specifications for TDD [if TDD not mandatory]
- /iikit-06-tasks - Generate task breakdown from plan
```
