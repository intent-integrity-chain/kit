# Parallel Execution Reference

Detailed protocol for dispatching `[P]` tasks concurrently via subagents during implementation.

## Capability Detection

Determine whether your runtime supports concurrent subagent dispatch:

- **Can dispatch concurrently**: You have a tool or mechanism to launch multiple independent agents that run simultaneously (e.g., Claude Code `Task` tool, OpenCode parallel workers).
- **Cannot dispatch concurrently**: Sub-agents run sequentially, or no subagent mechanism exists (e.g., Gemini CLI, Codex CLI).

If concurrent dispatch is unavailable, execute all tasks sequentially. The rest of this document still applies — batches simply run one task at a time.

## Orchestrator/Worker Model

The **orchestrator** is the main agent running the implement skill. **Workers** are subagents dispatched for individual tasks.

### Orchestrator Responsibilities
- Parse tasks.md and build the task graph
- Group `[P]` tasks into parallel batches
- Dispatch workers with appropriate context
- Collect worker results
- **Write to tasks.md** (mark tasks `[x]`) — only the orchestrator does this
- Detect file conflicts between worker outputs
- Halt on failure, advance on success

### Worker Responsibilities
- Implement the assigned task (write code, create files, run tests)
- Report back: success/failure, files created/modified, errors encountered
- **Do NOT write to tasks.md** — report completion to the orchestrator
- **Check constitutional rules before every file write** — same enforcement as §6 of the implement skill
- Query Tessl tiles independently if needed

## Subagent Context Construction

Each worker subagent must receive sufficient context to implement its task independently.

**Mandatory context** (always include):
- Constitutional enforcement rules (extracted MUST/SHALL/REQUIRED statements)
- The specific task description from tasks.md
- Relevant sections from spec.md (the user story this task belongs to)
- Technical context from plan.md (tech stack, project structure, conventions)

**Conditional context** (include when relevant):
- Data model definitions from data-model.md (if task involves models/entities)
- API contracts from contracts/ (if task involves endpoints)
- Test specifications from tests/test-specs.md (if task involves tests)
- Tessl tile availability info (if Tessl is installed)

Keep context focused — a worker implementing a single model file does not need the full API contract catalog.

## Within-Phase Protocol

For each phase:

1. **Identify eligible tasks**: Tasks whose dependencies are all marked `[x]`. Tasks already marked `[x]` are complete and never re-executed. If a phase has zero tasks (or all tasks are already `[x]`), the phase is immediately complete — advance to the next phase.
2. **Partition into batches**:
   - All eligible `[P]` tasks with no mutual dependencies form a batch
   - Non-`[P]` tasks run individually in dependency order (use task ID as tiebreaker when multiple siblings are eligible at the same depth)
   - If two `[P]` tasks share a dependency on each other, they cannot be in the same batch
   - **Dispatch priority**: If both a `[P]` batch and non-`[P]` individual tasks are eligible in the same iteration, dispatch the `[P]` batch first. Non-`[P]` tasks are dispatched in subsequent iterations after the batch completes.
3. **Dispatch batch**:
   - Launch one worker per task in the batch
   - Workers execute concurrently (or sequentially in fallback mode)
4. **Collect results**: Wait for all workers in the batch to complete
5. **Post-batch checks**:
   - Run file conflict detection (see below)
   - If TDD active, run full test suite after batch (see TDD section)
6. **Checkpoint**: Mark completed tasks `[x]` in tasks.md in a single write
7. **Repeat** with remaining and newly eligible tasks until the phase is complete

## Cross-Story Protocol

After Phase 2 (Foundational) completes, independent user stories may execute as parallel workstreams.

**Eligibility check**:
- Two story phases are independent if they share no task-level dependencies
- Verify no two stories modify the same files (check task descriptions for file paths)
- If stories share a foundational dependency, it must already be complete (Phase 2)

**If eligibility fails**: Do not use cross-story parallelism. Execute story phases in their defined order (the default phase-by-phase behavior). Intra-phase `[P]` batching still applies within each story phase.

**Dispatch**:
- Each workstream runs its story phase end-to-end (batches within)
- The orchestrator monitors all workstreams
- Each workstream reports progress independently

**Completion**:
- When a workstream finishes, the orchestrator marks its tasks `[x]`
- Run file conflict detection across workstream outputs
- Continue with the Final (Polish) phase only after all workstreams complete

**Workstream failure**: If a workstream fails, let other running workstreams finish. Mark their completed tasks `[x]`. Halt before the Final phase and report which workstream failed and why. After the user fixes the issue, resume only the failed workstream from its last checkpoint.

## File Conflict Detection

File conflicts are checked at two points:

**Pre-dispatch (best-effort)**: Before dispatching a batch or cross-story workstreams, check task descriptions for overlapping file paths. This catches obvious conflicts but is not exhaustive — task descriptions may not list every file a worker will create or modify. If pre-dispatch detects overlapping file paths, exclude the conflicting tasks from the batch and schedule them sequentially after the batch completes. Non-conflicting tasks in the batch proceed as planned.

**Post-batch (definitive)**: After each parallel batch or cross-story workstream completes:

1. Collect the list of files actually created or modified by each worker
2. Check for overlapping file paths between workers in the same batch
3. If overlap detected:
   ```
   FILE CONFLICT: src/models/user.py modified by T005 and T008
   Resolution required before proceeding.
   ```
4. Mark non-conflicting tasks `[x]`. Leave conflicting tasks unmarked until resolved.
5. Resolve by manually merging the changes, or sequentially re-run the conflicting tasks. Mark them `[x]` after resolution.

## TDD in Parallel Context

When TDD is active (test-specs.md exists):

**Per-worker**: Each worker follows the red/green cycle for its task:
- RED task (write test): Write test, run it, verify it **fails** (no implementation yet)
- GREEN task (implement): Write code, run test, verify it **passes**
- Workers can run tests for their own scope concurrently

**Post-batch (orchestrator)**: After a batch completes, run all tests that exist so far (not just the batch's tests) to catch integration issues between parallel implementations:
```
POST-BATCH TEST RUN: Batch N
Running all existing tests... X tests passed, Y failed
```

**RED-phase batches**: If all tasks in the batch are RED-phase (test-writing) tasks, test failures are **expected** — the halt condition does not apply. Instead, verify the new tests fail as expected and proceed. If any test unexpectedly *passes* during a RED-phase batch, halt and investigate (may indicate stale implementation code or an incorrect test).

**GREEN-phase and mixed batches**: If post-batch tests fail, halt and investigate before starting the next batch. Failures may indicate a file conflict or incompatible implementations between workers.

## Tessl in Parallel Context

When Tessl tiles are installed:

- Each worker queries `mcp__tessl__query_library_docs` independently for its own task
- Workers should not duplicate queries already made by the orchestrator
- The orchestrator aggregates Tessl usage tracking across all workers for the final report:
  ```
  TESSL_USAGE.documentation_queries += worker.queries
  TESSL_USAGE.skills_invoked += worker.skills
  ```
