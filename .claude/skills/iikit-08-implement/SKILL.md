---
name: iikit-08-implement
description: >-
  Execute the implementation plan by coding each task from tasks.md — writes source files, runs tests, verifies assertion integrity, and validates output against constitutional principles.
  Use when ready to build the feature, start coding, develop from the task list, or resume a partially completed implementation.
license: MIT
metadata:
  version: "1.6.4"
---

# Intent Integrity Kit Implement

Execute the implementation plan by processing all tasks in tasks.md.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

> **Windows**: Replace `bash …/iikit-core/scripts/bash/*.sh` with `pwsh …/iikit-core/scripts/powershell/*.ps1` (same flags, `-PascalCase`).

## Constitution Loading

Load constitution per [constitution-loading.md](../iikit-core/references/constitution-loading.md) (enforcement mode — extract rules, declare hard gate, validate before every file write).

## Prerequisites Check

1. Run: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase 08 --json`
2. Parse for `FEATURE_DIR` and `AVAILABLE_DOCS`. If missing tasks.md: ERROR.
3. If JSON contains `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). After user selects, run:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selection>
   ```
   Then re-run the prerequisites check from step 1.

## Bugfix Detection

Scan tasks.md for unchecked tasks (`[ ]`). If **every** unchecked task has a `T-B` prefix (bugfix tasks from `/iikit-bugfix`), this is a **bugfix-only run**. Set `BUGFIX_ONLY=true` for gate relaxation below.

## Pre-Implementation Validation

**Standard mode** (`BUGFIX_ONLY=false`):
1. **Artifact completeness**: constitution.md, spec.md (requirements + criteria), plan.md (tech context), tasks.md (has tasks), checklists/*.md (at least one)
2. **Cross-artifact consistency**: spec FR-XXX -> tasks, plan tech stack -> task file paths, constitution -> plan compliance
3. Report readiness: READY or BLOCKED

**Bugfix mode** (`BUGFIX_ONLY=true`):
1. **Artifact completeness**: tasks.md (has T-B tasks), bugs.md (has matching BUG-NNN entries). plan.md, checklists, and spec.md are NOT required.
2. **Cross-artifact consistency**: skip (bugfix tasks trace to bugs.md, not spec FR-XXX)
3. Report readiness: READY or BLOCKED

## Checklist Gating

**Skip entirely if `BUGFIX_ONLY=true`** — bugfix tasks are not gated on checklists.

Read each checklist in `FEATURE_DIR/checklists/`. All must be 100% complete. If incomplete: ask user to proceed or halt.

## Execution Flow

### 1. Load Context

**Standard mode**: Required: `tasks.md`, `plan.md`. Optional: `data-model.md`, `contracts/`, `research.md`, `quickstart.md`, `tests/test-specs.md`

**Bugfix mode**: Required: `tasks.md`, `bugs.md`. Optional: `plan.md`, `tests/test-specs.md` (present if TDD)

### 2. TDD Support Check

If `tests/test-specs.md` exists, verify assertion integrity:

```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh comprehensive-check "FEATURE_DIR/tests/test-specs.md" "CONSTITUTION.md"
```

Parse JSON response: `PASS` (proceed), `BLOCKED` (halt, show remediation), `WARN` (proceed with caution).

If TDD **mandatory** but test-specs.md missing: ERROR with `Run: /iikit-05-testify`.

### 2.1 Test Execution Enforcement

Tests **MUST** be run, not just written. After writing a test: run it immediately (expect red). After implementing: run it (expect green). If tests fail: fix code, not tests. Never mark a test task `[x]` without execution output.

```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/verify-test-execution.sh verify "FEATURE_DIR/tests/test-specs.md" "$(cat test-output.log)"
```

Block on any status other than `PASS`.

### 3. Tessl Integration

If Tessl installed, query tiles before implementing library code. See [tessl-integration.md](references/tessl-integration.md).

### 4. Project Setup

For scaffolding tools in existing directories, use force/overwrite flags. See [ignore-patterns.md](references/ignore-patterns.md) for gitignore patterns by stack.

### 5. Parse and Execute Tasks

**5.1 Task extraction**: parse tasks.md for phase, completion status (`[x]` = skip), dependencies, [P] markers, [USn] labels. Build in-memory task graph.

**5.2 Execution strategy — read [parallel-execution.md](references/parallel-execution.md) BEFORE proceeding**:
If tasks.md contains `[P]` markers, you **MUST** use the `Task` tool to dispatch parallel batches as concurrent subagents (one worker per task). Only fall back to sequential execution if the runtime has no subagent dispatch mechanism. Report mode per [formatting-guide.md](../iikit-core/references/formatting-guide.md) (Execution Mode Header).

**5.3 Phase-by-phase**:
1. Collect eligible tasks (dependencies satisfied)
2. Build parallel batches from [P] tasks with no mutual dependencies
3. Dispatch — parallel: launch one `Task` tool subagent per `[P]` task in the batch; sequential: one at a time
4. Collect results, checkpoint `[x]` in tasks.md per batch
5. Repeat until phase complete

Cross-story parallelism: independent stories can run as parallel workstreams after Phase 2 (verify no shared file modifications).

**5.4 Rules**: query Tessl tiles before library code, tests before code if TDD, run tests after writing them, only orchestrator updates tasks.md.

**5.5 Failure handling**: let in-flight siblings finish, mark successes, report failures, halt phase. Constitutional violations in workers: worker stops, reports to orchestrator, treated as task failure.

### 6. Output Validation

Before writing ANY file: review against constitutional principles. On violation: STOP, explain, suggest alternative.

### 7. Progress Tracking

Report after each task/batch. Mark completed `[x]` in tasks.md. Halt on failure.

### 8. Post-Fix GitHub Comment (Bug Fix Tasks)

After completing bug fix tasks (tasks with `T-B` prefix pattern):

1. Check if `FEATURE_DIR/bugs.md` exists
2. For each completed bug (all T-BNNN tasks for a BUG-NNN marked `[x]`):
   - Read the `GitHub Issue` field from the bug's entry in bugs.md
   - If a GitHub issue is linked (e.g., `#42`):
     - Post a comment via `gh issue comment <number> --body "<comment>"`
     - Comment content: root cause from bugs.md, list of completed fix tasks, and fix reference (current branch or latest commit)
   - If no GitHub issue is linked: skip silently
3. If `gh` CLI is unavailable: skip silently

### 9. Completion

All tasks `[x]`, features validated against spec, test execution enforcement (§2.1) satisfied, Tessl usage reported.

## Error Handling

| Condition | Response |
|-----------|----------|
| Tasks missing | STOP with run instructions |
| Plan missing (standard mode) | STOP with run instructions |
| Constitution violation | STOP, explain, suggest alternative |
| Checklist incomplete | Ask user, STOP if declined |
| Task/parallel failure | Report, halt (see 5.5) |
| Tests not run | STOP: execute first |
| Tests failing | Fix code, re-run |

## Next Steps

```
Implementation complete!
- Run tests to verify
- Commit and push
- /iikit-09-taskstoissues - (Optional) Export to GitHub Issues
```
