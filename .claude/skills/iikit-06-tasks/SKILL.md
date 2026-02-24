---
name: iikit-06-tasks
description: >-
  Generate dependency-ordered task breakdown from plan and specification.
  Use when breaking features into implementable tasks, planning sprints, or creating work items with parallel markers.
license: MIT
metadata:
  version: "1.6.4"
---

# Intent Integrity Kit Tasks

Generate an actionable, dependency-ordered tasks.md for the feature.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Constitution Loading

Load constitution per [constitution-loading.md](../iikit-core/references/constitution-loading.md) (basic mode — note TDD requirements for task ordering).

## Prerequisites Check

1. Run: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase 06 --json`
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase 06 -Json`
2. Parse JSON for `FEATURE_DIR` and `AVAILABLE_DOCS`. If missing plan.md: ERROR.
3. If JSON contains `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). After user selects, run:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selection>
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selection>`

   Then re-run the prerequisites check from step 1.
4. Checklist gate per [checklist-gate.md](../iikit-core/references/checklist-gate.md).

## Plan Readiness Validation

1. **Tech stack**: verify plan.md has Language/Version defined (WARNING if missing)
2. **User story mapping**: verify each story in spec.md has acceptance criteria
3. **Dependency pre-analysis**: identify shared entities used by multiple stories -> suggest Foundational phase

Report readiness per [formatting-guide.md](../iikit-core/references/formatting-guide.md) (Plan Readiness section).

## Execution Flow

### 1. Load Documents

- **Required**: `plan.md`, `spec.md`
- **Optional**: `data-model.md`, `contracts/`, `research.md`, `quickstart.md`, `tests/features/` (.feature files)

If .feature files exist (or legacy test-specs.md), tasks reference specific test IDs (e.g., "T012 [US1] Implement to pass TS-001").

### 2. Tessl Convention Consultation

If Tessl installed: query primary framework tile for project structure conventions and testing framework tile for test organization. Apply to file paths and task ordering. If not available: skip silently.

### 3. Generate Tasks

Extract tech stack from plan.md, user stories from spec.md, entities from data-model.md, endpoints from contracts/, decisions from research.md. Organize by user story with dependency graph and parallel markers.

### 4. Task Format (REQUIRED)

```text
- [ ] [TaskID] [P?] [Story?] Description with file path
```

- Checkbox: always `- [ ]`
- Task ID: sequential (T001, T002...)
- [P]: only if parallelizable (different files, no dependencies)
- [USn]: required for user story tasks only (not Setup/Foundational/Polish)
- Description: clear action with exact file path

**Examples**:
- `- [ ] T001 Create project structure per implementation plan` (setup, no story)
- `- [ ] T005 [P] Implement authentication middleware in src/middleware/auth.py` (parallel, no story)
- `- [ ] T012 [P] [US1] Create User model in src/models/user.py` (parallel, story)
- `- [ ] T014 [US1] Implement UserService in src/services/user_service.py` (sequential, story)

**Wrong** — missing required elements:
- `- [ ] Create User model` (no ID, no story label)
- `T001 [US1] Create model` (no checkbox)
- `- [ ] [US1] Create User model` (no task ID)

**Traceability**: When referencing multiple test spec IDs, enumerate them explicitly as a comma-separated list. Do NOT use English prose ranges like "TS-005 through TS-010" — these break automated traceability checks.

**Correct**: `[TS-005, TS-006, TS-007, TS-008, TS-009, TS-010]`
**Wrong**: `TS-005 through TS-010`

### 5. Phase Structure

- **Phase 1**: Setup (project initialization)
- **Phase 2**: Foundational (blocking prerequisites, complete before stories)
- **Phase 3+**: User Stories in priority order (P1, P2, P3...) — tests -> models -> services -> endpoints -> integration
- **Final**: Polish & Cross-Cutting Concerns

### 6. Task Organization

Map each component to its user story. Shared entities serving multiple stories go in Setup/Foundational. Each contract gets a contract test task. Story dependencies marked explicitly.

### 7. Dependency Graph Validation

After generating, validate:
1. **Circular dependencies**: detect cycles, ERROR if found with resolution options
2. **Orphan tasks**: warn about tasks with no dependencies and not blocking anything
3. **Critical path**: identify longest chain, suggest parallelization, list parallel batches per phase
4. **Phase boundaries**: no backward cross-phase dependencies
5. **Story independence**: warn on priority inversions (higher-priority depending on lower)

### 8. Write tasks.md

Use [tasks-template.md](../iikit-core/templates/tasks-template.md) with phases, dependencies, parallel examples, and implementation strategy.

## Report

Output: path to tasks.md, total count, count per story, parallel opportunities, MVP scope suggestion, format validation.

## Semantic Diff on Re-run

If tasks.md exists: preserve `[x]` completion status, map old IDs to new by similarity, warn about changes to completed tasks. Ask confirmation before overwriting. Use format from [formatting-guide.md](../iikit-core/references/formatting-guide.md) (Semantic Diff section).

## Next Steps

You MUST read [model-recommendations.md](../iikit-core/references/model-recommendations.md), check the expiration date (refresh via web search if expired), detect the agent via env vars, and include a model switch tip in the output below if the next phase needs a different model tier.

```
Tasks generated! Next steps:
- /iikit-07-analyze - (Recommended) Validate consistency
- /iikit-08-implement - Execute implementation (requires 100% checklist completion)
Tip: <model switch suggestion if tier mismatch, omit if already on the right model>
- Dashboard: file://$(pwd)/.specify/dashboard.html (resolve the path)
```
