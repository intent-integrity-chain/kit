---
name: iikit-08-implement
description: Execute implementation plan by processing all tasks in tasks.md
---

# Intent Integrity Kit Implement

Execute the implementation plan by processing and executing all tasks defined in tasks.md.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Constitution Loading (REQUIRED)

Before ANY action, load and internalize the project constitution:

1. Read constitution:
   ```bash
   cat CONSTITUTION.md 2>/dev/null || echo "NO_CONSTITUTION"
   ```

2. If file doesn't exist:
   ```
   ERROR: Project constitution not found at CONSTITUTION.md

   Cannot proceed without constitution.
   Run: /iikit-00-constitution
   ```

3. Parse all principles, constraints, and governance rules.

4. **Extract Enforcement Rules**: Find all MUST, MUST NOT, SHALL, REQUIRED, NON-NEGOTIABLE statements. These rules are checked BEFORE EVERY FILE WRITE.

5. **Hard Gate Declaration**:
   ```
   CONSTITUTION ENFORCEMENT GATE ACTIVE
   Extracted: X enforcement rules
   Mode: STRICT - violations HALT implementation
   ```

## Prerequisites Check

1. Run prerequisites check:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
   ```

2. Parse JSON for `FEATURE_DIR` and `AVAILABLE_DOCS`.

3. If error or missing `tasks.md`:
   ```
   ERROR: tasks.md not found in feature directory.
   Run: /iikit-06-tasks
   ```

## Pre-Implementation Validation

**BEFORE any implementation, perform complete validation sweep:**

### Artifact Completeness Check

| Artifact | Required | Check |
|----------|----------|-------|
| constitution.md | YES | Has principles section |
| spec.md | YES | Has Requirements + Success Criteria |
| plan.md | YES | Has Technical Context defined |
| tasks.md | YES | Has at least one task |
| checklists/*.md | YES | At least one checklist |

### Cross-Artifact Consistency

1. **Spec -> Tasks**: Every FR-XXX should have corresponding task(s)
2. **Plan -> Tasks**: Tech stack should match task file paths
3. **Constitution -> Plan**: Verify no constitution violations

### Readiness Score

Report: Artifacts complete, Spec coverage %, Plan alignment, Constitution compliance, Checklist status, Dependencies valid. Output READY or BLOCKED.

## Checklist Gating (CRITICAL)

1. Read each checklist file in `FEATURE_DIR/checklists/`
2. Count: Incomplete (`- [ ]`) vs Complete (`- [x]`)
3. **PASS**: All checklists 100% -> proceed
4. **FAIL**: Ask user to proceed or halt

## Launch Kanban Dashboard (Optional)

Before starting implementation, launch the live kanban dashboard so the user can watch progress in their browser.

**Unix/macOS/Linux:**
```bash
if command -v npx >/dev/null 2>&1; then
  npx iikit-kanban . &
  echo "[iikit] Kanban dashboard launching at http://localhost:3000"
else
  echo "[iikit] Kanban dashboard unavailable (npx not found). Install Node.js 18+ for live progress visualization."
fi
```

**Windows (PowerShell):**
```powershell
if (Get-Command npx -ErrorAction SilentlyContinue) {
  Start-Process npx -ArgumentList "iikit-kanban", "." -NoNewWindow
  Write-Host "[iikit] Kanban dashboard launching at http://localhost:3000"
} else {
  Write-Host "[iikit] Kanban dashboard unavailable (npx not found). Install Node.js 18+ for live progress visualization."
}
```

The dashboard shows user stories as kanban cards (Todo / In Progress / Done) with live-updating task checkboxes. As tasks are marked `[x]` in tasks.md, the board updates in the browser automatically.

If npx is not available, implementation continues normally without the visual dashboard.

## Execution Flow

### 1. Load Implementation Context

- **REQUIRED**: `tasks.md`, `plan.md`
- **IF EXISTS**: `data-model.md`, `contracts/`, `research.md`, `quickstart.md`, `tests/test-specs.md`

### 2. TDD Support Check

If `tests/test-specs.md` exists, perform assertion integrity verification:

**Step 1: Run comprehensive integrity check**
```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh comprehensive-check "FEATURE_DIR/tests/test-specs.md" "CONSTITUTION.md"
```

**Step 2: Parse the JSON response**
```json
{
    "overall_status": "PASS|BLOCKED|WARN",
    "block_reason": "...",
    "tdd_determination": "mandatory|optional|forbidden",
    "checks": {
        "context_hash": "valid|invalid|missing",
        "git_note": "valid|invalid|missing",
        "git_diff": "clean|modified|untracked"
    }
}
```

**Step 3: Act on results**

| overall_status | Action |
|----------------|--------|
| `PASS` | Proceed with implementation |
| `BLOCKED` | **HALT** - Display block_reason, require remediation |
| `WARN` | Display warning, proceed with caution |

**BLOCKED remediation:**
```
ASSERTION INTEGRITY CHECK FAILED

Status: BLOCKED
Reason: [block_reason from JSON]

The test assertions have been modified since testify ran.
This violates TDD principles - tests define expected behavior BEFORE implementation.

Remediation options:
1. Revert assertion changes: git checkout -- FEATURE_DIR/tests/test-specs.md
2. Re-run testify to regenerate test-specs: /iikit-05-testify
3. If legitimate spec changes occurred, update spec.md first, then re-run testify

Cannot proceed until assertion integrity is restored.
```

**Display circular verification warning:**
```
⚠️  TDD INTEGRITY ACTIVE

Test assertions are locked. During implementation:
- Fix CODE to pass tests, never modify assertions
- If a test seems wrong, re-run /iikit-05-testify from updated spec
- Assertion tampering will block future implementation runs
```

If TDD is **mandatory** in constitution but test-specs.md missing -> ERROR:
```
ERROR: TDD is MANDATORY per constitution but tests/test-specs.md not found.

Run: /iikit-05-testify

Cannot proceed without test specifications.
```

### 2.1 Test Execution Enforcement (CRITICAL)

**Tests MUST be run, not just written.** Writing tests without executing them defeats TDD.

**Mandatory rules:**
1. **After writing any test file**: Run the test immediately to verify it fails (red phase)
2. **After implementing code**: Run tests again to verify they pass (green phase)
3. **Before marking ANY test-related task complete**: Tests MUST have been executed with visible output
4. **"Run test suite" tasks**: Execute ALL tests (unit, integration, e2e) and verify pass/fail status

**What counts as "tests run":**
- Actual execution output showing test results (PASS/FAIL counts)
- NOT just "tests written" or "test file created"
- NOT assuming tests pass without running them

**Blocking conditions:**
- Cannot mark implementation complete if tests haven't been run
- Cannot mark "run tests" task as `[x]` without actual execution output
- If any tests fail, fix code (not tests) before proceeding

**Test execution commands by stack:**
| Stack | Command |
|-------|---------|
| Node/TypeScript | `npm test` or `npx vitest` or `npx jest` |
| Python | `pytest` or `python -m pytest` |
| Go | `go test ./...` |
| Rust | `cargo test` |
| E2E (Playwright) | `npx playwright test` |
| E2E (Cypress) | `npx cypress run` |

**Deterministic verification (REQUIRED):**

After running tests, verify execution with:

**Unix/macOS/Linux:**
```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/verify-test-execution.sh verify \
    "FEATURE_DIR/tests/test-specs.md" \
    "$(cat test-output.log)"
```

**Windows (PowerShell):**
```powershell
pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/verify-test-execution.ps1 verify `
    "FEATURE_DIR/tests/test-specs.md" `
    (Get-Content test-output.log -Raw)
```

The script returns JSON with status:
- `PASS` - All tests ran and passed
- `TESTS_FAILING` - Tests ran but some failed -> fix code
- `INCOMPLETE` - Fewer tests ran than expected in test-specs.md
- `NO_TESTS_RUN` - Could not detect test execution -> tests weren't run

**Block on any status other than `PASS`.**

### 3. Tessl Integration

If Tessl installed, use tiles for library documentation. See [tessl-integration.md](references/tessl-integration.md) for detailed patterns.

**Key rule**: Before implementing code using a tile's library, query `mcp__tessl__query_library_docs`.

### 4. Project Setup

**Scaffolding in existing directories**: When using project scaffolding tools (e.g., `create-next-app`, `create-vite`, `cargo init`, `go mod init`) in a directory with existing intent-integrity-kit artifacts, use force/overwrite flags to prevent conflicts:
- `npx create-next-app . --force`
- `npm create vite . -- --force`
- `cargo init --name project` (works in non-empty dirs)

The intent-integrity-kit files (`.specify/`, `.claude/`, `AGENTS.md`, etc.) won't be overwritten by these tools.

Create/verify ignore files based on tech stack. See [ignore-patterns.md](references/ignore-patterns.md) for patterns by technology.

### 5. Parse and Execute Tasks

#### 5.1 Task Extraction

Parse tasks.md and extract for each task:
- **Phase** membership (Phase 1, 2, 3+, Final)
- **Completion status** — `[x]` (complete) or `[ ]` (pending). Tasks already marked `[x]` are never re-executed.
- **Dependencies** (blockedBy / blocks relationships)
- **[P] marker** — task is safe to run concurrently with other `[P]` tasks in the same phase
- **[USn] label** — user story assignment (enables cross-story parallelism)

Build an in-memory task graph before executing anything. This handles both fresh starts and cold resumes from partially-completed tasks.md.

#### 5.2 Execution Strategy Selection

Determine whether you can dispatch multiple subagents concurrently:

- **If you can** (e.g., Claude Code `Task` tool, OpenCode parallel dispatch): use **Parallel mode**
- **If you cannot** (e.g., Gemini sequential sub-agents, Codex CLI, or no subagent support): use **Sequential mode**

Report the selected mode before starting:
```
EXECUTION MODE: [Parallel | Sequential]
Phases: X | Total tasks: Y | Completed: C | Remaining: R | Parallel batches: Z
```

See [parallel-execution.md](references/parallel-execution.md) for the full orchestrator/worker protocol.

#### 5.3 Phase-by-Phase Execution

For each phase in order:

1. **Collect eligible tasks** — tasks whose dependencies are all satisfied
2. **Build parallel batches** from eligible `[P]` tasks that share no mutual dependencies
3. **Dispatch the batch**:
   - *Parallel mode*: Launch one subagent per task in the batch concurrently. Each subagent receives the task description, relevant spec/plan context, and constitutional rules. Only the orchestrator (main agent) writes to tasks.md.
   - *Sequential mode*: Execute tasks in the batch one at a time
4. **Collect results** — wait for all tasks in the batch to complete
5. **Checkpoint** — mark completed tasks `[x]` in tasks.md (single write per batch)
6. **Repeat** until phase is done, then advance to the next phase

**Cross-story parallelism** (after Phase 2): If independent user stories have no shared dependencies, their phases can execute as parallel workstreams. Check that no two workstreams modify the same files before dispatching.

#### 5.4 Execution Rules

- Query Tessl tiles before implementing library code
- Tests before code if TDD
- **Run tests after writing them** — verify red/green cycle
- **Never mark test tasks complete without execution output**
- Mark completed tasks as `[x]` only after verification
- **Only the orchestrator updates tasks.md** — subagents report results back, they do not write to tasks.md directly

#### 5.5 Parallel Failure Handling

When one or more tasks fail during parallel execution:
1. **Let in-flight siblings finish** — do not cancel running tasks
2. **Collect all results** — record which tasks succeeded and which failed
3. **Mark successes** `[x]` in tasks.md
4. **Report each failure** with full error details
5. **Halt the phase** — do not start new batches until all failures are resolved

**Cross-story workstream failure**: If a workstream fails while other workstreams are running, let the other workstreams finish. Mark their completed tasks `[x]`. Then halt before the Final (Polish) phase and report the failed workstream.

**Constitutional violation in a worker**: The worker STOPs itself per §6 (does not write the violating file) and reports the violation to the orchestrator. The orchestrator treats this as a task failure for batch-management purposes: in-flight siblings are allowed to finish, successes are marked `[x]`, and the phase is halted. The batch completion report MUST label the violation distinctly (e.g., `T002: CONSTITUTIONAL VIOLATION — ...`).

**Resumption**: After the user fixes the issue, re-evaluate the halted phase from the task graph. Already-completed tasks (`[x]`) are skipped. Only remaining tasks are dispatched.

### 6. Output Validation (REQUIRED)

Before writing ANY file:
1. Review against EACH constitutional principle
2. If violation: STOP, explain, suggest alternative
3. If compliant: proceed

### 7. Progress Tracking

- Report after each task (sequential) or after each batch (parallel)
- Halt on non-parallel task failure; on parallel failure see §5.5
- Mark completed tasks `[x]` in tasks.md

**Batch completion report** (parallel mode):
```
Batch N complete: [T005 Y] [T006 Y] [T007 N]
  T005: Created user model (src/models/user.py)
  T006: Created auth middleware (src/middleware/auth.py)
  T007: FAILED — missing dependency, see error above
Progress: X/Y tasks complete
```

### 8. Completion

**Pre-completion checklist:**
- [ ] All tasks marked `[x]` in tasks.md
- [ ] Features validated against spec requirements
- [ ] **ALL tests executed** (not just written) with passing results
- [ ] Test output shown/logged as evidence
- [ ] Report Tessl tile usage if applicable

**CANNOT declare completion if:**
- Tests exist but were never run
- Test execution shows failures
- "Run test suite" task marked complete without actual execution

## Error Handling

| Condition | Response |
|-----------|----------|
| Tasks file missing | STOP: Run /iikit-06-tasks |
| Plan file missing | STOP: Run /iikit-03-plan |
| Constitution violation | STOP, explain, suggest alternative |
| Checklist incomplete | Ask user, STOP if declined |
| Task fails | Report error, halt sequential |
| Parallel task fails | Let siblings finish, collect results, mark successes, halt phase |
| Tests written but not run | STOP: Execute tests before marking complete |
| Tests failing | STOP: Fix code (not tests), re-run until green |

## Next Steps

```
Implementation complete! Next steps:
- Run tests to verify functionality
- Commit and push changes
- /iikit-09-taskstoissues - (Optional) Export tasks to GitHub Issues
```
