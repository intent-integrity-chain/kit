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
2. **BDD chain**: If `tests/features/` exists with `.feature` files, the BDD verification chain (sections 2.1–2.4) still applies — bugfix tests use the same BDD framework as feature tests.
3. **Cross-artifact consistency**: skip (bugfix tasks trace to bugs.md, not spec FR-XXX)
4. Report readiness: READY or BLOCKED

## Checklist Gating

**Skip entirely if `BUGFIX_ONLY=true`** — bugfix tasks are not gated on checklists.

Read each checklist in `FEATURE_DIR/checklists/`. All must be 100% complete. If incomplete: ask user to proceed or halt.

## Dashboard

Suggest the user open the dashboard to watch implementation progress in real time:
```
Dashboard: file://$(pwd)/.specify/dashboard.html (resolve the path) — updates live as tasks complete
```

## Execution Flow

### 1. Load Context

**Standard mode**: Required: `tasks.md`, `plan.md`. Optional: `data-model.md`, `contracts/`, `research.md`, `quickstart.md`, `tests/features/` (BDD .feature files)

**Bugfix mode**: Required: `tasks.md`, `bugs.md`. Optional: `plan.md`, `tests/features/` (if present, BDD chain applies — bugfix tests must use the same BDD framework)

### 2. TDD Support Check

If `tests/features/` directory exists (contains `.feature` files), verify assertion integrity:

```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh comprehensive-check "FEATURE_DIR/tests/features" "CONSTITUTION.md"
```

**Windows (PowerShell):**
```powershell
pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/testify-tdd.ps1 comprehensive-check "FEATURE_DIR/tests/features" "CONSTITUTION.md"
```

Parse JSON response: `PASS` (proceed), `BLOCKED` (halt, show remediation), `WARN` (proceed with caution).

If TDD **mandatory** but `tests/features/` missing or empty: ERROR with `Run: /iikit-05-testify`.

### 2.1 BDD Verification Chain Enforcement

When `.feature` files exist, the full BDD verification chain applies to each implementation task:

**Step 1 — Write step definitions**: Write step definition code that binds Gherkin steps to application calls. Place in `tests/step_definitions/`.

**Step 2 — Verify step coverage**: All `.feature` steps must have matching step definitions.
```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/verify-steps.sh --json "FEATURE_DIR/tests/features" "FEATURE_DIR/plan.md"
```
Must return `PASS` before continuing. If `BLOCKED`: fix missing step definitions. If `DEGRADED`: proceed with caution (no BDD framework available).

**Step 3 — RED phase**: Run the BDD tests. They MUST fail (step definitions exist but production code does not yet implement the behavior). This confirms the tests are meaningful.

**Step 4 — Write production code**: Implement the feature code that makes the tests pass.

**Step 5 — GREEN phase**: Run the BDD tests again. They MUST pass. If they fail: fix the production code, not the tests or `.feature` files.

**Step 6 — Verify step quality**: Ensure step definitions have meaningful assertions (not empty bodies or tautologies).
```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/verify-step-quality.sh --json "FEATURE_DIR/tests/step_definitions" "<language>"
```
Must return `PASS` before marking the task complete. If `BLOCKED`: fix the flagged step definitions.

### 2.2 Feature File Immutability

**CRITICAL**: `.feature` files MUST NOT be modified during implementation. They are generated by `/iikit-05-testify` and hash-locked. Only step definitions and production code may be modified. If a `.feature` file needs changes, re-run `/iikit-05-testify`.

### 2.3 Test Execution Enforcement

Tests **MUST** be run, not just written. After writing a test: run it immediately (expect red). After implementing: run it (expect green). If tests fail: fix code, not tests. Never mark a test task `[x]` without execution output.

```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/verify-test-execution.sh verify "FEATURE_DIR/tests/features" "$(cat test-output.log)"
```

Block on any status other than `PASS`.

### 2.4 Task Completion Gate

A task is NOT complete until:
1. `verify-steps.sh` returns `PASS` (all steps defined)
2. BDD tests pass (GREEN phase confirmed)
3. `verify-step-quality.sh` returns `PASS` (no empty/trivial assertions)

Do NOT mark `[x]` in tasks.md until all three gates pass.

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
4. Collect results, checkpoint `[x]` in tasks.md per batch, then commit per task (§5.6)
5. Repeat until phase complete

Cross-story parallelism: independent stories can run as parallel workstreams after Phase 2 (verify no shared file modifications).

**5.4 Rules**: query Tessl tiles before library code, tests before code if TDD, run tests after writing them, only orchestrator updates tasks.md.

**5.5 Failure handling**: let in-flight siblings finish, mark successes, report failures, halt phase. Constitutional violations in workers: worker stops, reports to orchestrator, treated as task failure.

**5.6 Task Commits**: After each task is marked `[x]`, stage its changed files (`git add` specific files, NOT `-A`) and commit:

- `<feature-id>` = `FEATURE_DIR` with `specs/` prefix and trailing `/` stripped (e.g. `001-user-auth`)
- Subject: `feat(<feature-id>): <task-id> <task description>` (use `fix(…)` for `T-B` tasks)
- Trailers: `iikit-feature: <feature-id>` and `iikit-task: <task-id>`
- Skip if no files changed; for parallel batches commit each task individually after batch completes
- After each commit, regenerate the dashboard so the board reflects the latest task state:
  ```bash
  bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/generate-dashboard-safe.sh
  ```

### 6. Output Validation

Before writing ANY file: review against constitutional principles. On violation: STOP, explain, suggest alternative.

### 7. Progress Tracking

Report after each task/batch. Mark completed `[x]` in tasks.md. Halt on failure.

### 8. Post-Fix GitHub Integration (Bug Fix Tasks)

After completing bug fix tasks (tasks with `T-B` prefix pattern):

1. Check if `FEATURE_DIR/bugs.md` exists
2. For each completed bug (all T-BNNN tasks for a BUG-NNN marked `[x]`):
   - Read the `GitHub Issue` field from the bug's entry in bugs.md
   - If a GitHub issue is linked (e.g., `#42`):
     - **Close via commit**: include `Fixes #<number>` in the last task's commit message (§5.6) — GitHub auto-closes the issue when pushed/merged
     - **Post a comment**: use `gh issue comment` if available, otherwise `curl` the GitHub API (`POST /repos/{owner}/{repo}/issues/{number}/comments`). Comment content: root cause from bugs.md, completed fix tasks, and fix reference
   - If no GitHub issue is linked: skip silently

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
- Push commits
- /iikit-09-taskstoissues - (Optional) Export to GitHub Issues
- Merge feature branch into main (if on a feature branch)
```

If on a feature branch, offer to merge. Ask the user which approach they prefer:
- **A) Merge locally**: `git checkout main && git merge <branch>`
- **B) Create PR**: `gh pr create` if available, otherwise provide the GitHub URL to create one manually
- **C) Skip**: user will handle it

You MUST read [model-recommendations.md](../iikit-core/references/model-recommendations.md), check the expiration date (refresh via web search if expired), detect the agent via env vars, and include a `Tip:` line in the Implementation complete block above if the next phase needs a different model tier.
