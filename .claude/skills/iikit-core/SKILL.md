---
name: iikit-core
description: >-
  Initialize an IIKit project, check feature progress, select the active feature, and display the workflow command reference.
  Use when starting a new project, running init, checking status, switching between features, or looking up available commands and phases.
license: MIT
metadata:
  version: "1.6.4"
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

Initialize intent-integrity-kit in the current directory. Handles the full project bootstrap: git init, optional GitHub repo creation, or cloning an existing repo. Optionally seeds the project backlog from an existing PRD/SDD document.

### Argument Parsing

The `$ARGUMENTS` after `init` may include an optional path or URL to a PRD/SDD document (e.g., `/iikit-core init ./docs/prd.md` or `/iikit-core init https://example.com/prd.md`). If present, store it as `prd_source` for use in Step 6.

### Execution Flow

#### Step 0 — Detect environment

```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/git-setup.sh --json
# Windows: pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/git-setup.ps1 -Json
```

JSON fields: `git_available`, `is_git_repo`, `has_remote`, `remote_url`, `is_github_remote`, `gh_available`, `gh_authenticated`, `has_iikit_artifacts`.

#### Step 1 — Git/GitHub setup

**Auto-skip**: If `is_git_repo` is true AND `has_remote` is true, skip straight to Step 2. Report: "Git repo with remote detected (`<remote_url>`), proceeding with IIKit init."

Otherwise, present applicable options (hide those whose prerequisites aren't met):

- **A) Initialize here** (requires `git_available`): `git init`. If `gh_available` + `gh_authenticated`, offer `gh repo create <name> --private --source . --push` (ask public/private).
- **B) Clone existing repo** (requires `gh_available` + `gh_authenticated`): Ask for repo. `gh repo clone <repo>`. If clone target differs from cwd, tell user to `cd` into it and re-run init.
- **C) Skip git setup** (always available): Proceed without git. Warn that assertion integrity hooks won't be installed.

If `git_available` is false, only C is available. Note that git is required for full functionality.

#### Step 2 — Check if already initialized

`test -f "CONSTITUTION.md"`

#### Step 3 — Create directory structure

`mkdir -p .specify specs`

#### Step 4 — Initialize hooks

```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/init-project.sh --json
# Windows: pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/init-project.ps1 -Json
```

Installs pre-commit (assertion validation) and post-commit (hash storage) hooks.

#### Step 5 — Report

Directories created, hook status. If PRD seeding will follow (Step 6 conditions are met), note that backlog seeding is next. Otherwise, suggest `/iikit-00-constitution`.

#### Step 6 — Seed backlog from PRD

**Gate**: Requires `is_github_remote` from Step 0 detection. If not met, skip with a note: "PRD seeding requires a GitHub remote. Skipping backlog seeding." Proceed to final report. For GitHub operations, use `gh` if available, otherwise fall back to `curl` with the GitHub API.

**Input resolution**:
- If `prd_source` was set from the init argument, use that.
- If no argument was provided, ask the user: "Start from scratch or seed from an existing requirements document?"
  - **A) From scratch** — Skip to final report.
  - **B) From existing document** — Ask the user for a file path or URL.

**Read document**: Read the file (local path via `Read` tool) or fetch the URL (via `WebFetch` tool). Support common formats: Markdown, plain text, PDF, HTML.

**Draft PREMISE.md**: Before extracting features, synthesize the document into a `PREMISE.md` at the project root. Include:
- **What**: one-paragraph description of the application/system
- **Who**: target users/personas
- **Why**: the problem being solved and the value proposition
- **Domain**: the business/technical domain and key terminology
- **High-level scope**: major system boundaries and components

Write the draft to `PREMISE.md`. Note to the user that `/iikit-00-constitution` will review and finalize it.

**Extract and order features**: Parse the document and extract distinct features/epics. For each feature, extract:
- A short title (imperative, max 80 chars)
- A 1-3 sentence description
- Priority if mentioned (P1/P2/P3), default P2

Order features in logical implementation sequence: foundational/core features first (data models, auth, shared services), then backend, then frontend, then integration/polish. Features that other features depend on come earlier.

**Present for reordering**: Show the ordered features as a numbered table with columns: #, Title, Description, Priority, Rationale (why this position). Ask the user to confirm the order, reorder, remove, or add features. Wait for explicit confirmation before proceeding.

**Create labels and issues**: Follow the commands and body template in [prd-issue-template.md](templates/prd-issue-template.md). Create labels first (idempotent), then one issue per confirmed feature in the confirmed order.

**Final report**: List all created issues with their numbers and titles. Suggest `/iikit-00-constitution` as the next step, then `/iikit-01-specify #<issue-number>` to start specifying individual features.

### If Already Initialized

Show constitution status, feature count, and suggest `/iikit-core status`.

## Subcommand: status

### Execution Flow

1. Run:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase status --json
   # Windows: pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase status -Json
   ```

2. **Present results** (all logic is in script output — just display):
   - Project name, `feature_stage`, artifact status (`artifacts` object), checklist progress (`checklist_checked`/`checklist_total`), `ready_for` phase, `next_step`
   - If `clear_before` is true, prepend `/clear` suggestion. If `next_step` is null, report feature as complete.

## Subcommand: use

Select the active feature when multiple features exist in `specs/`.

### User Input

The `$ARGUMENTS` after `use` is the feature selector: a number (`1`, `001`), partial name (`user-auth`), or full directory name (`001-user-auth`).

### Execution Flow

1. Run:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selector>
   # Windows: pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selector>
   ```
   Parse JSON for `active_feature` and `stage`.

2. **Report** active feature, stage, and suggest next command: `specified` → `/iikit-02-clarify` or `/iikit-03-plan` | `planned` → `/iikit-04-checklist` or `/iikit-06-tasks` | `tasks-ready` → `/iikit-08-implement` | `implementing-NN%` → `/iikit-08-implement` (resume) | `complete` → done. Suggest `/clear` before next skill when appropriate.

If no selector, no match, or ambiguous match: show available features with stages and ask user to pick.

## Subcommand: help (also default when no subcommand)

Display the workflow reference from [help-reference.md](references/help-reference.md) verbatim.

## Resources

- [spec-template.md](templates/spec-template.md), [plan-template.md](templates/plan-template.md), [agent-file-template.md](templates/agent-file-template.md) — feature scaffolding
- [prd-issue-template.md](templates/prd-issue-template.md) — PRD backlog seeding
- [help-reference.md](references/help-reference.md) — workflow command reference

## Error Handling

Unknown subcommand → show help. Not in a project → suggest `init`. Git unavailable → warn but continue.
