---
name: iikit-bugfix
description: >-
  Report a bug against an existing feature — creates a structured bugs.md record, generates fix tasks in tasks.md, and optionally imports from or creates GitHub issues.
  Use when fixing a bug, reporting a defect, importing a GitHub issue into the workflow, or triaging an error without running the full specification process.
license: MIT
metadata:
  version: "1.6.4"
---

# Intent Integrity Kit Bugfix

Report a bug against an existing feature, create a structured `bugs.md` record, and generate fix tasks in `tasks.md`.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Constitution Loading

Load constitution per [constitution-loading.md](../iikit-core/references/constitution-loading.md) (soft mode — warn if missing, proceed without).

## Execution Flow

The text after `/iikit-bugfix` is either a `#number` (GitHub issue) or a text bug description.

### 1. Parse Input

Determine the input type:

- **`#number` pattern** (e.g., `#42`): GitHub inbound flow (Step 2a)
- **Text description**: Text description flow (Step 2b)
- **Empty**: ERROR with usage example: `/iikit-bugfix 'Login fails when email contains plus sign'` or `/iikit-bugfix #42`

If input contains BOTH `#number` and text, prioritize the `#number` and warn that text is ignored.

### 2a. GitHub Inbound Flow

1. Fetch issue: use `gh issue view <number> --json title,body,labels` if available, otherwise `curl` the GitHub API (`GET /repos/{owner}/{repo}/issues/{number}`)
2. If fetch fails (issue not found, auth error, or no GitHub remote configured): ERROR with clear message and remediation; suggest using text description instead.
3. Map fields:
   - `title` → bug description
   - `body` → reproduction steps
   - `labels` → severity: "critical" → critical, "high"/"priority" → high, "bug" → medium (default), otherwise → medium
4. Store issue number for GitHub Issue field in bugs.md
5. Continue to Step 3

### 2b. Text Description Flow

1. Store the text as the bug description
2. Continue to Step 3

### 3. Select Feature & Full Setup

Run full setup to list features, validate, and get bug ID and task IDs. First, present feature list to user. After selection:

**Unix/macOS/Linux:**
```bash
bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/bugfix-helpers.sh --full-setup "<feature_dir>" <task_count>
```
**Windows (PowerShell):**
```powershell
pwsh .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/bugfix-helpers.ps1 --full-setup "<feature_dir>" <task_count>
```

Use `task_count` = 2 if TDD mandatory (from `tdd_determination` in response), 3 otherwise.

Parse JSON for: `features` (list for display), `validation` (check `valid`), `bug_id` (BUG-NNN), `task_ids` (T-BNNN array), `tdd_determination`.

If `validation.valid` is false: ERROR with the message. If `features` is empty: ERROR with "No features found."

### 4. Gather Bug Details

**For text input (2b):**
- Prompt user for **severity**: present options (critical, high, medium, low) with descriptions
- Prompt user for **reproduction steps**: numbered list of steps to reproduce

**For GitHub inbound (2a):**
- Severity is pre-filled from labels (confirm with user if mapping is ambiguous)
- Reproduction steps are pre-filled from issue body (confirm with user)

### 5. Write bugs.md

Create or append to `<feature_dir>/bugs.md` using the template at [bugs-template.md](references/bugs-template.md).

Fill in:
- **BUG-ID**: from Step 3
- **Reported**: today's date (YYYY-MM-DD)
- **Severity**: from Step 4
- **Status**: `reported`
- **GitHub Issue**: `#number` if from GitHub inbound, `_(none)_` otherwise
- **Description**: bug description
- **Reproduction Steps**: from Step 4
- **Root Cause**: `_(empty until investigation)_`
- **Fix Reference**: `_(empty until implementation)_`

If `bugs.md` already exists, append with `---` separator before the new entry. Do NOT modify existing entries.

If `bugs.md` does not exist, create it with the header `# Bug Reports: <feature-name>` followed by the entry.

### 6. Outbound GitHub Issue (Text Input Only)

For text-input bugs only (NOT for GitHub inbound — issue already exists):

1. Create issue: use `gh issue create --title "<description>" --body "<bugs.md entry content>" --label "bug"` if `gh` available, otherwise `curl` the GitHub API (`POST /repos/{owner}/{repo}/issues`)
2. Store returned issue number in the bugs.md GitHub Issue field
3. If no GitHub remote configured: warn that GitHub issue creation was skipped, proceed with local workflow

### 7. TDD & Task Generation

Use `tdd_determination` and `task_ids` from Step 3. Use `bug_id` from Step 3.

### 8. BDD/TDD Flow (If Mandatory)

If TDD is mandatory (`determination` = `mandatory`):

1. Create `<feature_dir>/tests/features/` if it doesn't exist
2. Create `<feature_dir>/tests/features/bugfix_<BUG-NNN>.feature`:
   ```gherkin
   @BUG-NNN
   Feature: Bug fix for BUG-NNN — <description>
     Scenario: <description>
       Given <conditions that trigger the bug>
       When <action that causes incorrect behavior>
       Then <expected correct behavior>
   ```
3. Re-hash the features directory:
   ```bash
   bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh rehash "<feature_dir>/tests/features"
   ```
4. **Verify hash was stored** — if result is NOT `valid`, STOP and report error:
   ```bash
   bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh verify-hash "<feature_dir>/tests/features"
   ```
5. Continue to Step 9 with TDD task variant

### 9. Generate Bug Fix Tasks

Use `task_ids` from Step 3. Task IDs use `T-B` prefix — parsers and dashboard rely on this.

**Non-TDD task set** (`determination` is NOT `mandatory`, count = 3):
```markdown
## Bug Fix Tasks

- [ ] T-BNNN [BUG-NNN] Investigate root cause for BUG-NNN: <description>
- [ ] T-BNNN+1 [BUG-NNN] Implement fix for BUG-NNN: <description>
- [ ] T-BNNN+2 [BUG-NNN] Write regression test for BUG-NNN: <description>
```

**TDD task set** (`determination` = `mandatory`, count = 2). The TS-NNN reference MUST point to the test spec created in Step 8:
```markdown
## Bug Fix Tasks

- [ ] T-BNNN [BUG-NNN] Implement fix for BUG-NNN referencing test spec TS-NNN: <description>
- [ ] T-BNNN+1 [BUG-NNN] Verify fix passes test TS-NNN for BUG-NNN: <description>
```

If a GitHub issue is linked, include its reference in task descriptions (e.g., `(GitHub #42)`).

Append to existing `<feature_dir>/tasks.md`. If tasks.md does not exist, create it with:
```markdown
# Tasks: <feature-name>

## Bug Fix Tasks

[tasks here]
```

Do NOT modify existing entries or task IDs in tasks.md.

### 10. Commit, Dashboard & Next Steps

**Unix/macOS/Linux:**
```bash
bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/post-phase.sh --phase bugfix --commit-files "specs/*/bugs.md,specs/*/tasks.md,specs/*/tests/features/" --commit-msg "bugfix: <BUG-ID> <short-description>"
```
**Windows (PowerShell):**
```powershell
pwsh .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/post-phase.ps1 -Phase bugfix -CommitFiles "specs/*/bugs.md,specs/*/tasks.md,specs/*/tests/features/" -CommitMsg "bugfix: <BUG-ID> <short-description>"
```

Parse `next_step` from JSON. Present per [model-recommendations.md](../iikit-core/references/model-recommendations.md):
```
Bug reported!
Next: [/clear → ] <next_step> (model: <tier>)
[- <alt_step> — <reason> (model: <tier>)]
- Dashboard: file://$(pwd)/.specify/dashboard.html
```

## Error Handling

| Condition | Response |
|-----------|----------|
| Empty input | ERROR with usage example |
| No features found | ERROR: "Run `/iikit-01-specify` first" |
| Feature validation failed | ERROR with specific message |
| GitHub API unreachable | Fall back: `gh` → `curl` GitHub API → skip with WARN |
| GitHub issue not found | ERROR with "verify issue number" |
| TDD required, no test artifacts | ERROR: "Run `/iikit-04-testify` first" |
| Existing bugs.md | Append without modifying existing entries |
| Existing tasks.md | Append without modifying existing entries |
