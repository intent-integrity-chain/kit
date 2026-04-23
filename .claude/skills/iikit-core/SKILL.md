---
name: iikit-core
description: >-
  Initialize an IIKit (Intent Integrity Kit) project, check IIKit feature progress, select the active IIKit feature, and display the IIKit workflow command reference.
  Use when starting a new IIKit project, running IIKit init or setup, checking IIKit status, switching between IIKit features, looking up IIKit available commands and phases, or asking for help with the IIKit workflow.
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

> **Working directory**: All script paths are relative to the project root (the directory containing `tessl.json` or `.tessl/`). If a script path doesn't resolve, search with: `find . -path "*/iikit-core/scripts/bash/<script>.sh" 2>/dev/null || find ~/.tessl -path "*/iikit-core/scripts/bash/<script>.sh" 2>/dev/null`

#### Step 0 — Detect environment, initialize hooks, check premise

```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/init-full.sh --json
# Windows: pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/init-full.ps1 -Json
```

Parse JSON for `git` (environment), `init` (hooks), and `premise` (validation) sections.

- `git.gh_available` false → suggest installing GitHub CLI
- `init.git_user_configured` false → ask user for name/email, run `git config`

#### Step 1 — Git/GitHub setup

**Auto-skip**: If `git.is_git_repo` + `git.has_remote`, skip to Step 2.

Choose from available options (hide any whose prerequisites aren't met):

- **A) Init here** — requires `git.git_available`: run `git init`, then offer GitHub repo creation (`gh` or API); ask public/private.
- **B) Clone** — requires `git.git_available`: ask for URL or `owner/name`; run `gh repo clone` or `git clone`.
- **C) Skip** — always available: proceed without git; warn that assertion integrity hooks won't be active.

If `git_available` is false, only option C is available.

#### Step 2 — Check if already initialized

`test -f "CONSTITUTION.md"`

#### Step 3 — Create directory structure

`mkdir -p .specify specs`

#### Step 4 — Create PREMISE.md

If `premise.status` is `FAIL` or PREMISE.md doesn't exist: create from user's input using [premise-template.md](templates/premise-template.md). Extract:
- **What**: project description (from the user's input text)
- **Who**: target users (infer from context, or ask)
- **Why**: problem being solved (infer from context, or ask)
- **Domain**: business/technical domain
- **Scope**: system boundaries

Replace ALL bracket placeholders `[PLACEHOLDER]` with actual content. This is MANDATORY — init is not complete without PREMISE.md.

After writing PREMISE.md, validate:
```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/validate-premise.sh --json
```
If validation fails (remaining placeholders or missing sections), fix and re-validate.

#### Step 5 — Report

Directories created, hook status, PREMISE.md status. Suggest `/iikit-00-constitution`. Recommend installing companion `juliusbrussee/caveman` (`tessl i juliusbrussee/caveman`) and activating `/caveman full` at session start — ~30% cost and wall-clock savings measured across the IIKit workflow.

#### Step 6 — Seed backlog from PRD (optional)

**Gate**: Requires `is_github_remote` AND user provided a PRD/SDD document. If not met, skip silently.

Follow the detailed procedure in [prd-seeding.md](references/prd-seeding.md): resolve input → read document → extract and order features → present for user confirmation → create GitHub issues.

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

2. **Report** active feature, stage, and suggest next command: `specified` → `/iikit-clarify` or `/iikit-02-plan` | `planned` → `/iikit-03-checklist` or `/iikit-05-tasks` | `testified` → `/iikit-05-tasks` | `tasks-ready` → `/iikit-07-implement` | `implementing-NN%` → `/iikit-07-implement` (resume) | `complete` → done. Suggest `/clear` before next skill when appropriate.

If no selector, no match, or ambiguous match: show available features with stages and ask user to pick.

## Subcommand: help (also default when no subcommand)

Display the workflow reference from [help-reference.md](references/help-reference.md) verbatim.

## Resources

- [spec-template.md](templates/spec-template.md), [plan-template.md](templates/plan-template.md), [agent-file-template.md](templates/agent-file-template.md) — feature scaffolding
- [prd-issue-template.md](templates/prd-issue-template.md) — PRD backlog seeding
- [help-reference.md](references/help-reference.md) — workflow command reference

## Error Handling

Unknown subcommand → show help. Not in a project → suggest `init`. Git unavailable → warn but continue.
