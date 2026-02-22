---
name: iikit-07-analyze
description: >-
  Validate cross-artifact consistency — checks that every spec requirement traces to tasks, plan tech stack matches task file paths, and constitution principles are satisfied across all artifacts.
  Use when running a consistency check, verifying requirements traceability, detecting conflicts between design docs, or auditing alignment before implementation begins.
license: MIT
metadata:
  version: "1.7.6"
---

# Intent Integrity Kit Analyze

Non-destructive cross-artifact consistency analysis across spec.md, plan.md, and tasks.md.

## Operating Constraints

- **READ-ONLY** (exceptions: writes `analysis.md` and `.specify/score-history.json`). Never modify spec, plan, or task files.
- **Constitution is non-negotiable**: conflicts are automatically CRITICAL.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Constitution Loading

Load constitution per [constitution-loading.md](../iikit-core/references/constitution-loading.md) (basic mode — ERROR if missing). Extract principle names and normative statements.

## Prerequisites Check

1. Run: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase 07 --json`
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase 07 -Json`
2. Derive paths: SPEC, PLAN, TASKS from FEATURE_DIR. ERROR if any missing.
3. If JSON contains `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). After user selects, run:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selection>
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selection>`

   Then re-run the prerequisites check from step 1.
4. Checklist gate per [checklist-gate.md](../iikit-core/references/checklist-gate.md).

## Execution Steps

### 1. Load Artifacts (Progressive)

From spec.md: overview, requirements, user stories, edge cases.
From plan.md: architecture, data model refs, phases, constraints.
From tasks.md: task IDs, descriptions, phases, [P] markers, file paths.

### 2. Build Semantic Models

- Requirements inventory (functional + non-functional)
- User story/action inventory with acceptance criteria
- Task coverage mapping (task -> requirements/stories)
- Plan coverage mapping (requirement ID → plan.md sections where referenced)
- Constitution rule set

### 3. Detection Passes (limit 50 findings)

**A. Duplication**: near-duplicate requirements -> consolidate
**B. Ambiguity**: vague terms (fast, scalable, secure) without measurable criteria; unresolved placeholders
**C. Underspecification**: requirements missing objects/outcomes; stories without acceptance criteria; tasks referencing undefined components
**D. Constitution Alignment**: conflicts with MUST principles; missing mandated sections. For each principle, report status using these exact values:
- `ALIGNED` — principle satisfied across all artifacts
- `VIOLATION` — principle violated (auto-CRITICAL severity)
**E. Phase Separation Violations**: per [phase-separation-rules.md](../iikit-core/references/phase-separation-rules.md) — tech in constitution, implementation in spec, governance in plan
**F. Coverage Gaps**: requirements with zero tasks; tasks with no mapped requirement; non-functional requirements not in tasks; requirements not referenced in plan.md

> **Plan coverage detection**: Scan plan.md for each requirement ID (FR-xxx, SC-xxx). A requirement is "covered by plan" if its ID appears anywhere in plan.md. Collect contextual refs (KDD-x, section headers) where found.

**G. Inconsistency**: terminology drift; entities in plan but not spec; conflicting requirements

**H. Feature File Traceability** (when `FEATURE_DIR/tests/features/` exists):
Parse all `.feature` files in `tests/features/` and extract Gherkin tags:
- `@FR-XXX` — functional requirement references
- `@US-XXX` — user story references
- `@TS-XXX` — test specification IDs

**H1. Untested requirements**: For each FR-XXX in spec.md, check if at least one `.feature` file has a corresponding `@FR-XXX` tag. Flag any FR-XXX without a matching tag as "untested requirement" (severity: HIGH).

**H2. Orphaned tags**: For each `@FR-XXX` tag found in `.feature` files, verify the referenced ID exists in spec.md. Flag tags referencing non-existent IDs as "orphaned traceability tag" (severity: MEDIUM).

**H3. Step definition coverage** (optional): If `tests/step_definitions/` exists alongside `tests/features/`, run `verify-steps.sh` to check for undefined steps:
```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/verify-steps.sh --json "FEATURE_DIR/tests/features" "FEATURE_DIR/plan.md"
```
If status is BLOCKED, report undefined steps as findings (severity: HIGH). If DEGRADED, note in report but do not flag as finding.

### 4. Severity

- **CRITICAL**: constitution MUST violations, phase separation, missing core artifact, zero-coverage blocking requirement
- **HIGH**: duplicates, conflicting requirements, ambiguous security/performance, untestable criteria
- **MEDIUM**: terminology drift, missing non-functional coverage, underspecified edge cases
- **LOW**: style/wording, minor redundancy

### 5. Analysis Report

Output to console AND write to `FEATURE_DIR/analysis.md`:

```markdown
## Specification Analysis Report

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|

**Constitution Alignment**: principle name -> status (ALIGNED | VIOLATION) -> notes
**Coverage Summary**: requirement key -> has task? -> task IDs -> has plan? -> plan refs
**Phase Separation Violations**: artifact, line, violation, severity
**Metrics**: total requirements, total tasks, coverage %, ambiguity count, critical issues

**Health Score**: <score>/100 (<trend>)

## Score History

| Run | Score | Coverage | Critical | High | Medium | Low | Total |
|-----|-------|----------|----------|------|--------|-----|-------|
| <timestamp> | <score> | <coverage>% | <critical> | <high> | <medium> | <low> | <total_findings> |
```

### 5b. Score History

After computing **Metrics** in step 5, persist the health score:

1. **Compute health score**: `score = 100 - (critical*20 + high*5 + medium*2 + low*0.5)`, floored at 0, rounded to nearest integer.
2. **Read** `.specify/score-history.json`. If the file does not exist, initialize with `{}`.
3. **Append** a new entry for the current feature (keyed by feature directory name, e.g. `001-user-auth`):
   ```json
   { "timestamp": "<ISO-8601 UTC>", "score": <n>, "coverage_pct": <n>, "critical": <n>, "high": <n>, "medium": <n>, "low": <n>, "total_findings": <n> }
   ```
4. **Write** the updated object back to `.specify/score-history.json`.
5. **Determine trend** by comparing the new score to the previous entry (if any):
   - Score increased → `↑ improving`
   - Score decreased → `↓ declining`
   - Score unchanged or no previous entry → `→ stable`
6. **Display** in console output: `Health Score: <score>/100 (<trend>)`
7. **Include** the full `score_history` array for the current feature in `analysis.md` under the **Health Score** line and **Score History** table added in step 5.

### 6. Next Actions

- CRITICAL issues: recommend resolving before `/iikit-08-implement`
- LOW/MEDIUM only: may proceed with improvement suggestions

### 7. Offer Remediation

Ask: "Suggest concrete remediation edits for the top N issues?" Do NOT apply automatically.

## Operating Principles

- Minimal high-signal tokens, progressive disclosure, limit to 50 findings
- Never modify files, never hallucinate missing sections
- Prioritize constitution violations, use specific examples over exhaustive rules
- Report zero issues gracefully with coverage statistics

## Next Steps

You MUST read [model-recommendations.md](../iikit-core/references/model-recommendations.md), check the expiration date (refresh via web search if expired), detect the agent via env vars, and include a model switch tip in the output below if the next phase needs a different model tier.

```
Analysis complete!
- CRITICAL issues found: resolve, then re-run /iikit-07-analyze
- No CRITICAL: /clear then /iikit-08-implement (implementation benefits from max context)
Tip: <model switch suggestion if tier mismatch, omit if already on the right model>
- Dashboard: file://REPO_ROOT/.specify/dashboard.html
```
