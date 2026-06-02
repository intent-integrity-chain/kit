---
name: iikit-01-specify
description: >-
  Create a feature specification from a natural language description — generates user stories with Given/When/Then scenarios, functional requirements (FR-XXX), success criteria, and a quality checklist.
  Use when starting a new feature, writing a PRD, defining user stories, capturing acceptance criteria, or documenting requirements for a product idea.
license: MIT
metadata:
  version: "1.6.4"
---

# Intent Integrity Kit Specify

Process steps in order. Do not skip ahead.

Create or update a feature specification from a natural language description.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Constitution Loading

Load constitution per [constitution-loading.md](../iikit-core/references/constitution-loading.md) (soft mode — warn if missing, proceed without).

The text after `/iikit-01-specify` **is** the feature description.

## Step 1 — Bug-Fix Intent Detection

Analyze the description using **contextual analysis** (not keyword-only) to determine primary intent: **fix existing broken behavior** vs. **add new capability**.

- **Bug-fix signals**: "fix", "crash", "broken", "bug", "doesn't work", "fails", "error" — when describing broken existing behavior.
- **Not bug-fix**: "Add error handling", "Implement crash recovery" — these describe new capabilities, not fixes.

If bug-fix intent is detected:
1. Display: "This sounds like a bug fix. Consider using `/iikit-bugfix` instead."
2. Show example: `/iikit-bugfix '<the user description>'`
3. Ask the user to confirm: proceed with specification (genuinely a new feature) or switch to `/iikit-bugfix`
4. User confirms new feature → proceed to Step 2; user wants bugfix → stop.

## Step 2 — Generate Branch Name

Create 2-4 word action-noun name from description:
- "I want to add user authentication" -> "user-auth"
- "Implement OAuth2 integration for the API" -> "oauth2-api-integration"

## Step 3 — Create Feature Branch and Directory

Check current branch. If on main/master/develop, suggest creating feature branch (default). If already on feature branch, suggest skipping.

**Unix/macOS/Linux:**
```bash
bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/create-new-feature.sh --json "$ARGUMENTS" --short-name "your-short-name"
# Add --skip-branch if user declined branch creation
```
**Windows (PowerShell):**
```powershell
pwsh .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/create-new-feature.ps1 -Json "$ARGUMENTS" -ShortName "your-short-name"
# Add -SkipBranch if user declined
```

Parse JSON for `BRANCH_NAME`, `SPEC_FILE`, `FEATURE_NUM`. Only run ONCE per feature.

## Step 4 — Generate Specification

1. Parse user description — if empty: ERROR with usage example
2. Extract key concepts: actors, actions, data, constraints
3. For unclear aspects: make informed guesses. Only use `[NEEDS CLARIFICATION: question]` (max 3) when choice significantly impacts scope and no reasonable default exists
4. Fill User Scenarios with independently testable stories (P1, P2, P3 priorities)
5. Generate Functional Requirements (testable, with reasonable defaults)
6. Define Success Criteria (measurable, technology-agnostic)
7. Identify Key Entities (if data involved)

Write to `SPEC_FILE` using [spec-template.md](../iikit-core/templates/spec-template.md) structure.

## Step 5 — Phase Separation Validation

Scan for implementation details per [phase-separation-rules.md](../iikit-core/references/phase-separation-rules.md) (Specification section). Auto-fix violations, re-validate until clean.

## Step 6 — Create Spec Quality Checklist

Generate `FEATURE_DIR/checklists/requirements.md` covering: content quality (no implementation details), requirement completeness, feature readiness.

## Step 7 — Handle Clarifications

If `[NEEDS CLARIFICATION]` markers remain, present each as a question with options table and wait for user response.

## Step 8 — Report

Output: branch name, spec file path, checklist results, readiness for next phase.

## Guidelines

- Focus on **WHAT** users need and **WHY** — avoid HOW
- Written for business stakeholders, not developers
- Success criteria: measurable, technology-agnostic, user-focused, verifiable

## Semantic Diff on Re-run

If spec.md already exists: extract semantic elements (stories, requirements, criteria), compare with new content per [formatting-guide.md](../iikit-core/references/formatting-guide.md) (Semantic Diff section), show downstream impact warnings, ask confirmation before overwriting.

## Commit, Dashboard & Next Steps

Run post-phase to commit, refresh dashboard, and compute next step in a single call:

```bash
bash .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/post-phase.sh --phase 01 --commit-files "specs/*/spec.md,specs/*/checklists/requirements.md,.specify/active-feature" --commit-msg "spec: <feature-short-name> specification"
```
Windows: `pwsh .tessl/plugins/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/post-phase.ps1 -Phase 01 -CommitFiles "specs/*/spec.md,specs/*/checklists/requirements.md,.specify/active-feature" -CommitMsg "spec: <feature-short-name> specification"`

Parse `next_step` from JSON. Present per [model-recommendations.md](../iikit-core/references/model-recommendations.md):
```
Specification complete!
Next: [/clear → ] <next_step> (model: <tier>)
[- <alt_step> — <reason> (model: <tier>)]
- Dashboard: file://$(pwd)/.specify/dashboard.html
```
