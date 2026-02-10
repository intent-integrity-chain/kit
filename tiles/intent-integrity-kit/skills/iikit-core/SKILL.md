---
name: iikit-core
description: Initialize intent-integrity-kit project, check status, and display workflow help
---

# Intent Integrity Kit Core

Core skill providing project initialization, status checking, and workflow help.

## User Input

```text
$ARGUMENTS
```

Parse the user input to determine which subcommand to execute.

## Subcommands

This skill supports three subcommands:

1. **init** - Initialize intent-integrity-kit in a new or existing project
2. **status** - Show current project and feature status
3. **help** - Display workflow phases and command reference

If no subcommand is provided, show help.

## Subcommand: init

Initialize intent-integrity-kit in the current directory.

### Execution Flow

1. **Check if already initialized**:
   ```bash
   test -f "CONSTITUTION.md" && echo "ALREADY_INITIALIZED"
   ```

2. **Create directory structure**:
   ```bash
   mkdir -p .specify
   mkdir -p specs
   ```

3. **Initialize Git (if needed)**:

   **Unix/macOS/Linux:**
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/init-project.sh --json
   ```

   **Windows (PowerShell):**
   ```powershell
   pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/init-project.ps1 -Json
   ```

4. **Install Git Hooks**:

   The `init-project.sh` / `init-project.ps1` scripts automatically install two git hooks:

   **Pre-commit hook** — Validates assertion integrity before each commit. Checks that `test-specs.md` assertions haven't been tampered with since `/iikit-05-testify` generated them. Compares against both `context.json` hashes and git notes.

   **Post-commit hook** — Stores assertion hashes as git notes after each commit that includes `test-specs.md`. This creates tamper-resistant hash storage in git's object database, closing the gap where an agent could modify both `test-specs.md` and `context.json` to bypass the pre-commit check.

   Both hooks use the same three installation modes:
   - **No existing hook** — installs directly as `.git/hooks/<hook-type>`
   - **Existing IIKit hook** (has marker comment) — updates in place
   - **Existing non-IIKit hook** — installs as `.git/hooks/iikit-<hook-type>` and appends a one-line call to the existing hook

   Both hooks are thin wrappers that source `testify-tdd.sh` at runtime — when the framework updates, hooks pick up the latest logic automatically.

5. **Report**:
   ```
   Intent Integrity Kit initialized!

   Directory structure created:
   - .specify/           (IIKit working directory)
   - specs/              (feature specifications)

   Pre-commit hook: [installed/updated/installed alongside existing hook]
   Post-commit hook: [installed/updated/installed alongside existing hook]

   Next step: /iikit-00-constitution (creates CONSTITUTION.md)
   ```

### If Already Initialized

```
Intent Integrity Kit is already initialized in this project.

Current status:
- Constitution: [exists/missing]
- Features: X feature directories in specs/

Run /iikit-core status for detailed status.
```

## Subcommand: status

Show the current project and feature status.

### Execution Flow

1. **Get paths and status**:

   **Unix/macOS/Linux:**
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --json --paths-only
   ```

   **Windows (PowerShell):**
   ```powershell
   pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly
   ```

2. **Check constitution**:
   ```bash
   test -f "CONSTITUTION.md" && echo "CONSTITUTION_EXISTS"
   ```

3. **List features**:
   ```bash
   ls -d specs/[0-9][0-9][0-9]-*/ 2>/dev/null | wc -l
   ```

4. **For current feature, check artifacts**:
   - spec.md
   - plan.md
   - tasks.md
   - checklists/
   - tests/test-specs.md

5. **Report**:
   ```
   ╭─────────────────────────────────────────────╮
   │  IIKIT STATUS                            │
   ├─────────────────────────────────────────────┤
   │  Project:        [project name]             │
   │  Constitution:   [exists/missing]      [✓/✗]│
   │  Features:       X total                    │
   │                                             │
   │  Current Feature: [NNN-feature-name]        │
   │  ─────────────────────────────────────────  │
   │  spec.md:        [exists/missing]      [✓/✗]│
   │  plan.md:        [exists/missing]      [✓/✗]│
   │  tasks.md:       [exists/missing]      [✓/✗]│
   │  checklists/:    [X files]                  │
   │  test-specs.md:  [exists/missing]      [✓/✗]│
   ├─────────────────────────────────────────────┤
   │  Next Step: [recommended command]           │
   ╰─────────────────────────────────────────────╯
   ```

### Next Step Logic

Determine the recommended next step based on what's missing:

1. No constitution → `/iikit-00-constitution`
2. No feature → `/iikit-01-specify <description>`
3. Has spec, no plan → `/iikit-03-plan`
4. Has plan, no tasks → `/iikit-06-tasks`
5. Has tasks → `/iikit-08-implement`

## Subcommand: help

Display the complete workflow reference.

### Output

```
╭─────────────────────────────────────────────────────────────────────╮
│  IIKIT WORKFLOW                                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Phase 0: Foundation                                                │
│  ─────────────────────                                              │
│  /iikit-core init      Initialize intent-integrity-kit in a project           │
│  /iikit-00-constitution Define project governance principles      │
│                                                                     │
│  Phase 1: Specification                                             │
│  ──────────────────────                                             │
│  /iikit-01-specify     Create feature spec from description       │
│  /iikit-02-clarify     Resolve ambiguities (max 5 questions)      │
│                                                                     │
│  Phase 2: Planning                                                  │
│  ────────────────                                                   │
│  /iikit-03-plan        Create technical implementation plan       │
│  /iikit-04-checklist   Generate quality checklists                │
│                                                                     │
│  Phase 3: Testing (Optional unless constitutionally required)       │
│  ───────────────────────────────────────────────────────────        │
│  /iikit-05-testify     Generate test specifications (TDD)         │
│                                                                     │
│  Phase 4: Task Breakdown                                            │
│  ───────────────────────                                            │
│  /iikit-06-tasks       Generate task breakdown                    │
│  /iikit-07-analyze     Validate cross-artifact consistency        │
│                                                                     │
│  Phase 5: Implementation                                            │
│  ───────────────────────                                            │
│  /iikit-08-implement   Execute implementation                     │
│  /iikit-09-taskstoissues Export tasks to GitHub Issues            │
│                                                                     │
│  Utility Commands                                                   │
│  ────────────────                                                   │
│  /iikit-core status    Show project/feature status                │
│  /iikit-core help      Display this help                          │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  TIP: Each command validates its prerequisites automatically.       │
│       Run /iikit-core status to see your current progress.        │
╰─────────────────────────────────────────────────────────────────────╯
```

## Default (No Subcommand)

If user runs `/iikit-core` without arguments, show the help output.

## Error Handling

| Condition | Response |
|-----------|----------|
| Unknown subcommand | Show help with error message |
| Not in a project directory | Suggest running `init` |
| Git not available | Warning but continue (scripts handle this) |
