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

**MUST NOT contain**: technology stack, frameworks, databases, implementation details, specific tools or versions. These belong in `/iikit-03-plan`. See [phase-separation-rules.md](../iikit-core/references/phase-separation-rules.md).

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Prerequisites Check

1. Check if constitution exists: `cat CONSTITUTION.md 2>/dev/null || echo "NO_CONSTITUTION"`
2. If missing, copy from [constitution-template.md](../iikit-core/templates/constitution-template.md)

## Premise Check

Before starting the constitution, handle `PREMISE.md` (app-wide context: what, who, why, domain, scope):

- **If `PREMISE.md` exists** (drafted from PRD by init): present it to the user for review. Ask if anything needs changing. Update if needed.
- **If `PREMISE.md` is missing**: copy from [premise-template.md](../iikit-core/templates/premise-template.md), then ask the user to describe the project — what it is, who it's for, the problem it solves, the domain, and high-level scope. Fill in the template from their answers. Present for confirmation, then write.

The premise is content-specific (what we're building); the constitution is content-agnostic (how we build). Both live at the project root.

## Execution Flow

1. **Load existing constitution** — identify placeholder tokens `[ALL_CAPS_IDENTIFIER]`. Adapt to user's needs (more or fewer principles than template).

1.1. **Generate Dashboard** (optional, never blocks):
```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/generate-dashboard-safe.sh
```
Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/generate-dashboard-safe.ps1`

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

8. **Write** to `CONSTITUTION.md`

9. **Git init** (if needed): `git init` to ensure project isolation

10. **Commit**: `git add CONSTITUTION.md PREMISE.md && git commit -m "Initialize intent-integrity-kit project with constitution and premise"`

11. **Report**: version, bump rationale, git status, suggested next steps

## Formatting

- Markdown headings per template, lines <100 chars, single blank line between sections, no trailing whitespace.

## Next Steps

You MUST read [model-recommendations.md](../iikit-core/references/model-recommendations.md), check the expiration date (refresh via web search if expired), detect the agent via env vars, and include a model switch tip in the output below if the next phase needs a different model tier.

```
Constitution ready! Next: /iikit-01-specify
Tip: <model switch suggestion if tier mismatch, omit if already on the right model>
- Dashboard: file://$(pwd)/.specify/dashboard.html (resolve the path)
```
