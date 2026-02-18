# Formatting Guide

Standard output formats for reports, diffs, and status displays across all skills.

## Status Reports

Use bordered box format for key status displays:

```
+-----------------------------------------------------+
|  REPORT TITLE                                        |
+-----------------------------------------------------+
|  Field 1:        value                         [Y/N] |
|  Field 2:        value                         [Y/N] |
|  Field 3:        value                               |
+-----------------------------------------------------+
|  STATUS: [PASS/FAIL/READY/BLOCKED]                   |
+-----------------------------------------------------+
```

### Skill-Specific Reports

**Spec Quality (plan)**: Requirements count, success criteria, user stories, measurable criteria, unresolved clarifications, coverage %. Score X/10.

**Plan Readiness (tasks)**: Tech stack defined, user stories with criteria, shared entities, API contracts, research decisions.

**TDD Assessment (testify)**: Determination (mandatory/optional/forbidden), confidence, evidence, reasoning.

**Testify Complete**: TDD assessment, test counts by source (acceptance/contract/validation), output path, hash status (LOCKED).

**Dependency Graph (tasks)**: Total tasks, circular deps, orphans, critical path depth, phase boundaries, story independence, parallel opportunities.

**Readiness Score (implement)**: Artifact completeness, spec coverage %, plan alignment, constitution compliance, checklist status, dependencies.

**Batch Completion (implement, parallel mode)**:
```
Batch N complete: [T005 Y] [T006 Y] [T007 N]
  T005: Created user model (src/models/user.py)
  T006: Created auth middleware (src/middleware/auth.py)
  T007: FAILED — reason
Progress: X/Y tasks complete
```

## Semantic Diff Format

When re-running a skill over an existing artifact:

```
+-----------------------------------------------------+
|  SEMANTIC DIFF: [filename]                           |
+-----------------------------------------------------+
|  [Category 1]:                                       |
|    + Added: [items]                                  |
|    ~ Changed: [items]                                |
|    - Removed: [items]                                |
|                                                      |
|  [Category 2]:                                       |
|    + Added: [items]                                  |
|    ~ Changed: [items]                                |
+-----------------------------------------------------+
|  DOWNSTREAM IMPACT:                                  |
|  ! [artifact] MUST be regenerated ([reason])         |
|  ! [artifact] may need updates                       |
+-----------------------------------------------------+
```

For tasks.md re-runs, additionally show completion status preservation:
```
|  COMPLETION STATUS:                                  |
|    Previously completed: X tasks                     |
|    Mapped to new tasks: Y tasks                      |
|    Lost (task removed): Z tasks                      |
```

## Violation Reports

For phase separation, constitution, or integrity violations:

```
VIOLATION DETECTED: [violation type]

[artifact] contains [violation category]:
- [list each violation with location]

[Content type] belongs in [correct artifact/phase].
ACTION: [auto-fixing / requiring manual fix]
```

## Coverage Tables

For analysis and validation:

```markdown
| Requirement Key | Has Task? | Task IDs | Has Plan? | Plan Refs | Notes |
|-----------------|-----------|----------|-----------|-----------|-------|
```

## Execution Mode Header (implement)

```
EXECUTION MODE: [Parallel | Sequential]
Phases: X | Total tasks: Y | Completed: C | Remaining: R | Parallel batches: Z
```
