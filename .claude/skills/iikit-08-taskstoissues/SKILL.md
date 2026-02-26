---
name: iikit-08-taskstoissues
description: >-
  Convert tasks from tasks.md into GitHub Issues with labels and dependencies.
  Use when exporting work items to GitHub, setting up project boards, or assigning tasks to team members.
license: MIT
metadata:
  version: "1.6.4"
---

# Intent Integrity Kit Tasks to Issues

Convert existing tasks into dependency-ordered GitHub issues for project tracking.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Prerequisites Check

1. Run prerequisites check:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase 08 --json
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase 08 -Json`

2. Parse JSON for `FEATURE_DIR` and `AVAILABLE_DOCS`. Extract path to **tasks.md**.
3. If JSON contains `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). After user selects, run:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selection>
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selection>`

   Then re-run the prerequisites check from step 1.

## GitHub Remote Validation

```bash
git config --get remote.origin.url
```

**CRITICAL**: Only proceed if remote is a GitHub URL (`git@github.com:` or `https://github.com/`). Otherwise ERROR.

## Execution Flow

### 1. Parse tasks.md

Extract: Task IDs, descriptions, phase groupings, parallel markers [P], user story labels [USn], dependencies.

### 2. Create GitHub Issues

**Title format**: `[FeatureID/TaskID] [Story] Description` — feature-id extracted from `FEATURE_DIR` (e.g. `001-user-auth`).

**Body**: use template from [issue-body-template.md](references/issue-body-template.md). **Labels** (create if needed): `iikit`, `phase-N`, `us-N`, `parallel`.

### 3. Create Issues (parallel)

Use the `Task` tool to dispatch issue creation in parallel — one subagent per chunk of tasks (split by phase or user story). Each subagent receives:
- The chunk of tasks to create issues for
- The feature-id, repo owner/name, and label set
- Instructions to use `gh issue create` if available, otherwise `curl` the GitHub API

```bash
# Preferred:
gh issue create --title "[001-user-auth/T012] [US1] Create User model" --body "..." --label "iikit,phase-3,us-1"
```

**CRITICAL**: Never create issues in repositories that don't match the remote URL. Verify before dispatching.

Collect all created issue numbers from subagents. Verify all returned successfully before proceeding. If some failed: report failures, continue with successful issues only.

### 4. Link Dependencies

After all issues exist, edit bodies to add cross-references using `#NNN` syntax. Skip dependency links for any issues that failed to create.

## Report

Output: issues created (count + numbers), failures (count + details), link to repo issues list.

## Error Handling

| Condition | Response |
|-----------|----------|
| Not a GitHub remote | STOP with error |
| Issue creation fails | Report, continue with remaining issues |
| Partial failure | Link dependencies for successful issues only |

## Next Steps

Run: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/next-step.sh --phase 08 --json`
Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/next-step.ps1 -Phase 08 -Json`

Parse the JSON and present:
1. `next_step` will be null (workflow complete)
2. If `alt_steps` non-empty: list as alternatives
3. Append dashboard link

If on a feature branch, offer to merge:
- **A) Merge locally**: `git checkout main && git merge <branch>`
- **B) Create PR**: `gh pr create`
- **C) Skip**: user will handle it

Format:
```
Issues exported! Review in GitHub, assign team members, add to project boards.
- Dashboard: file://$(pwd)/.specify/dashboard.html (resolve the path)
```
