---
name: iikit-core
description: >-
  Initialize an IIKit project, check feature progress, select the active feature, and display the workflow command reference.
  Use when starting a new project, running init, checking status, switching between features, or looking up available commands and phases.
license: MIT
metadata:
  version: "1.6.7"
---

# Intent Integrity Kit Core

Core skill providing project initialization, status checking, and workflow help.

## User Input

```text
$ARGUMENTS
```

Parse the user input to determine which subcommand to execute.

## Subcommands

1. **init** - Initialize intent-integrity-kit in a new or existing project
2. **status** - Show current project and feature status
3. **use** - Select the active feature for multi-feature projects
4. **help** - Display workflow phases and command reference

If no subcommand is provided, show help.

## Subcommand: init

Initialize intent-integrity-kit in the current directory.

### Execution Flow

1. **Check if already initialized**: `test -f "CONSTITUTION.md"`

2. **Create directory structure**: `mkdir -p .specify specs`

3. **Initialize Git and install hooks**:

   **Unix/macOS/Linux:**
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/init-project.sh --json
   ```
   **Windows (PowerShell):**
   ```powershell
   pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/init-project.ps1 -Json
   ```

   The script installs two git hooks:
   - **Pre-commit**: validates assertion integrity before each commit
   - **Post-commit**: stores assertion hashes as tamper-resistant git notes

   Both use three installation modes: direct install, update existing IIKit hook, or install alongside existing non-IIKit hook.

4. **Report**: directories created, hook status, suggest `/iikit-00-constitution`

### If Already Initialized

Show constitution status, feature count, and suggest `/iikit-core status`.

## Subcommand: status

### Execution Flow

1. **Get deterministic status**:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase status --json
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase status -Json`

2. **Present results** (pure presentation — all logic is in the script output):
   - Parse the JSON response
   - Show project name and `feature_stage`
   - Show artifact status from `artifacts` object (exists/valid for each)
   - Show checklist progress from `checklist_checked`/`checklist_total`
   - Show `ready_for` phase
   - Show `next_step` as the recommended next command
   - If `clear_before` is true, prepend `/clear` suggestion before the next step command
   - If `next_step` is null, report feature as complete

## Subcommand: use

Select the active feature when multiple features exist in `specs/`.

### User Input

The `$ARGUMENTS` after `use` is the feature selector: a number (`1`, `001`), partial name (`user-auth`), or full directory name (`001-user-auth`).

### Execution Flow

1. **Run**:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selector>
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selector>`

2. Parse JSON for `active_feature` and `stage`.

3. **Report**: confirm which feature is now active, its current stage, and suggest the appropriate next command based on stage:
   - `specified` -> `/iikit-02-clarify` or suggest `/clear`, then `/iikit-03-plan`
   - `planned` -> `/iikit-04-checklist` or suggest `/clear`, then `/iikit-06-tasks`
   - `tasks-ready` -> suggest `/clear`, then `/iikit-08-implement`
   - `implementing-NN%` -> suggest `/clear`, then `/iikit-08-implement` (resume)
   - `complete` -> All done

### Error Handling

| Condition | Response |
|-----------|----------|
| No selector provided | Show available features with stages, ask user to pick |
| No match | Show available features |
| Ambiguous match | Show matching features, ask to be more specific |

## Subcommand: help

Display the complete workflow reference:

```
Phase 0: Foundation
  /iikit-core init        Initialize project
  /iikit-core use         Select active feature
  /iikit-00-constitution  Define governance principles

Phase 1: Specification
  /iikit-01-specify       Create feature spec
  /iikit-02-clarify       Resolve ambiguities

Phase 2: Planning
  /iikit-03-plan          Create implementation plan
  /iikit-04-checklist     Generate quality checklists

Phase 3: Testing (optional unless constitutionally required)
  /iikit-05-testify       Generate test specifications

Phase 4: Task Breakdown
  /iikit-06-tasks         Generate task breakdown
  /iikit-07-analyze       Validate consistency

Phase 5: Implementation
  /iikit-08-implement     Execute implementation
  /iikit-09-taskstoissues Export to GitHub Issues

Each command validates its prerequisites automatically.
Run /iikit-core status to see your current progress.
```

## Default (No Subcommand)

Show help output.

## Error Handling

| Condition | Response |
|-----------|----------|
| Unknown subcommand | Show help with error message |
| Not in a project directory | Suggest running `init` |
| Git not available | Warning but continue |
