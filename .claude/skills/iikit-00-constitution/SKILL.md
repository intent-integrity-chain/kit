---
name: iikit-00-constitution
description: >-
  Create or update a CONSTITUTION.md that defines project governance — establishes coding standards, quality gates, TDD policy, review requirements, and non-negotiable development principles with versioned amendment tracking.
  Use when defining project rules, setting up coding standards, establishing quality gates, configuring TDD requirements, or creating non-negotiable development principles.
license: MIT
metadata:
  version: "1.6.4"
---

# Intent Integrity Kit Constitution

Create or update the project constitution at `CONSTITUTION.md` — the governing principles for specification-driven development.

## Scope

**MUST contain**: governance principles, non-negotiable development rules, quality standards, amendment procedures, compliance expectations.

**MUST NOT contain**: technology stack, frameworks, databases, implementation details, specific tools or versions. These belong in `/iikit-02-plan`. See [phase-separation-rules.md](../iikit-core/references/phase-separation-rules.md).

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Prerequisites Check

1. **Check PREMISE.md exists**: `test -f PREMISE.md`. If missing: ERROR — "PREMISE.md not found. Run `/iikit-core init` first to create it." Do NOT proceed without PREMISE.md.
2. **Validate PREMISE.md**:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/validate-premise.sh --json
   ```
   If FAIL (missing sections or placeholders): ERROR — show details, suggest re-running init.
3. Check if constitution exists: `cat CONSTITUTION.md 2>/dev/null || echo "NO_CONSTITUTION"`
4. If missing, copy from [constitution-template.md](../iikit-core/templates/constitution-template.md)

## Execution Flow

1. **Load existing constitution** — identify placeholder tokens `[ALL_CAPS_IDENTIFIER]`. Adapt to user's needs (more or fewer principles than template).

2. **Collect values for placeholders**:
   - From user input, or infer from repo context
   - `RATIFICATION_DATE`: original adoption date
   - `LAST_AMENDED_DATE`: today if changes made
   - `CONSTITUTION_VERSION`: semver (MAJOR: principle removal/redefinition, MINOR: new principle, PATCH: clarifications)

3. **Draft content**: replace all placeholders, preserve heading hierarchy, ensure each principle has name + rules + rationale, governance section covers amendment/versioning/compliance.

4. **Consistency check**: validate against [plan-template.md](../iikit-core/templates/plan-template.md), [spec-template.md](../iikit-core/templates/spec-template.md), [tasks-template.md](../iikit-core/templates/tasks-template.md).

5. **Sync Impact Report** (HTML comment at top): version change, modified principles, added/removed sections, follow-up TODOs.

6. **Validate**: no remaining bracket tokens, version matches report, dates in ISO format, principles are declarative and testable. Constitution MUST have at least 3 principles — if fewer, add more based on the project context.

7. **Phase separation validation**: scan for technology-specific content per [phase-separation-rules.md](../iikit-core/references/phase-separation-rules.md). Auto-fix violations, re-validate until clean.

8. **Write TWO files** — both are required outputs of this skill:

   **a) Write `CONSTITUTION.md`** with the finalized constitution content.

   **b) Write `.specify/context.json`** with the TDD determination extracted from the constitution you just wrote. All downstream skills (testify, bugfix, implement) read TDD policy from this file. Determine the value from the constitution text:
   - Constitution contains MUST/REQUIRED + "TDD", "test-first", or "red-green-refactor" → `mandatory`
   - Constitution contains MUST + "test-driven" or "tests before code" → `mandatory`
   - Constitution contains MUST + "test-after" or "no unit tests" → `forbidden`
   - Testing is described as OPTIONAL or SHOULD → `optional`
   - No testing policy stated → `optional`

   Create the file:
   ```bash
   mkdir -p .specify
   ```
   Write `.specify/context.json` containing at minimum:
   ```json
   {
     "tdd_determination": "<mandatory|optional|forbidden>"
   }
   ```
   If `.specify/context.json` already exists, merge (don't overwrite other fields). You can use `jq` if available, or write the file directly.

   **Verify**: confirm `.specify/context.json` exists and contains `tdd_determination`.

9. **Git init** (if needed): `git init` to ensure project isolation

10. **Commit**: `git add CONSTITUTION.md .specify/context.json && git commit -m "Add project constitution"`

11. **Dashboard Refresh** (optional, never blocks):
```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/generate-dashboard-safe.sh
```
Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/generate-dashboard-safe.ps1`

12. **Report**: version, bump rationale, TDD determination, git status, suggested next steps

## Formatting

- Markdown headings per template, lines <100 chars, single blank line between sections, no trailing whitespace.

## Next Steps

Run: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/next-step.sh --phase 00 --json`
Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/next-step.ps1 -Phase 00 -Json`

Parse the JSON and present:
1. If `clear_after` is true: suggest `/clear` before proceeding
2. Present `next_step` as the primary recommendation
3. If `alt_steps` non-empty: list as alternatives
4. For `next_step` and each `alt_step`, include the `model_tier` from the JSON so the user knows which model is best for each option. Look up tiers in [model-recommendations.md](../iikit-core/references/model-recommendations.md) for agent-specific switch commands.
5. Append dashboard link

Format:
```
Constitution ready!
Next: [/clear → ] <next_step> (model: <tier>)
[- <alt_step> — <reason> (model: <tier>)]

- Dashboard: file://$(pwd)/.specify/dashboard.html (resolve the path)
```
