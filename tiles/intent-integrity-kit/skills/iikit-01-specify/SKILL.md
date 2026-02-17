---
name: iikit-01-specify
description: >-
  Create feature specification from natural language description.
  Use when starting a new feature, writing requirements, defining user stories, or capturing acceptance criteria.
license: MIT
---

# Intent Integrity Kit Specify

Create or update a feature specification from a natural language description.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Constitution Loading

Load constitution per [constitution-loading.md](../iikit-core/references/constitution-loading.md) (soft mode — warn if missing, proceed without).

## Execution Flow

The text after `/iikit-01-specify` **is** the feature description.

### 0. Bug-Fix Intent Detection

Before proceeding with feature specification, analyze the user description for bug-fix intent using **contextual analysis** (not keyword-only):

**Bug-fix signals** (keywords in a fixing context): "fix", "crash", "broken", "bug", "doesn't work", "fails", "error" when used to describe existing broken behavior.

**NOT bug-fix** (keywords in a new-feature context): "Add error handling", "Implement crash recovery", "Create bug tracking" — these describe new capabilities, not fixes to existing behavior.

**Decision rule**: Is the primary intent to **fix existing broken behavior** or to **add new capability**? Keywords alone are insufficient — evaluate the full description.

If bug-fix intent is detected:
1. Display: "This sounds like a bug fix. Consider using `/iikit-bugfix` instead."
2. Show example: `/iikit-bugfix '<the user description>'`
3. Ask the user to confirm: proceed with specification (it's genuinely a new feature) or switch to `/iikit-bugfix`
4. If the user confirms it is a new feature: proceed to Step 1
5. If the user wants bugfix: stop and suggest they run `/iikit-bugfix`

### 1. Generate Branch Name

Create 2-4 word action-noun name from description:
- "I want to add user authentication" -> "user-auth"
- "Implement OAuth2 integration for the API" -> "oauth2-api-integration"

### 2. Create Feature Branch and Directory

Check current branch. If on main/master/develop, suggest creating feature branch (default). If already on feature branch, suggest skipping.

**Unix/macOS/Linux:**
```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/create-new-feature.sh --json "$ARGUMENTS" --short-name "your-short-name"
# Add --skip-branch if user declined branch creation
```
**Windows (PowerShell):**
```powershell
pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/create-new-feature.ps1 -Json "$ARGUMENTS" -ShortName "your-short-name"
# Add -SkipBranch if user declined
```

Parse JSON for `BRANCH_NAME`, `SPEC_FILE`, `FEATURE_NUM`. Only run ONCE per feature.

### 3. Generate Specification

1. Parse user description — if empty: ERROR with usage example
2. Extract key concepts: actors, actions, data, constraints
3. For unclear aspects: make informed guesses. Only use `[NEEDS CLARIFICATION: question]` (max 3) when choice significantly impacts scope and no reasonable default exists
4. Fill User Scenarios with independently testable stories (P1, P2, P3 priorities)
5. Generate Functional Requirements (testable, with reasonable defaults)
6. Define Success Criteria (measurable, technology-agnostic)
7. Identify Key Entities (if data involved)

Write to `SPEC_FILE` using [spec-template.md](../iikit-core/templates/spec-template.md) structure.

### 4. Phase Separation Validation

Scan for implementation details per [phase-separation-rules.md](../iikit-core/references/phase-separation-rules.md) (Specification section). Auto-fix violations, re-validate until clean.

### 5. Create Spec Quality Checklist

Generate `FEATURE_DIR/checklists/requirements.md` covering: content quality (no implementation details), requirement completeness, feature readiness.

### 6. Handle Clarifications

If `[NEEDS CLARIFICATION]` markers remain, present each as a question with options table and wait for user response.

### 7. Report

Output: branch name, spec file path, checklist results, readiness for next phase.

## Guidelines

- Focus on **WHAT** users need and **WHY** — avoid HOW
- Written for business stakeholders, not developers
- Success criteria: measurable, technology-agnostic, user-focused, verifiable

## Semantic Diff on Re-run

If spec.md already exists: extract semantic elements (stories, requirements, criteria), compare with new content per [formatting-guide.md](../iikit-core/references/formatting-guide.md) (Semantic Diff section), show downstream impact warnings, ask confirmation before overwriting.

## Next Steps

```
Specification complete! Next steps:
- /iikit-02-clarify - (Recommended) Resolve ambiguities
- /iikit-03-plan - Create technical implementation plan
```
