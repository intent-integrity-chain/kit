---
name: iikit-06-analyze
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

1. Run:
   - Bash: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase 06 --json`
   - Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase 06 -Json`
2. Derive paths: SPEC, PLAN, TASKS from FEATURE_DIR. ERROR if any missing.
3. If JSON contains `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). After user selects, run:
   - Bash: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selection>`
   - Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selection>`

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
- Task coverage mapping (task → requirements/stories)
- Plan coverage mapping (requirement ID → plan.md sections where referenced)
- Constitution rule set

### 3. Detection Passes (limit 50 findings)

| Pass | Category | What to detect |
|------|----------|----------------|
| **A** | Duplication | Near-duplicate requirements → consolidate |
| **B** | Ambiguity | Vague terms (fast, scalable, secure) without measurable criteria; unresolved placeholders |
| **C** | Underspecification | Requirements missing objects/outcomes; stories without acceptance criteria; tasks referencing undefined components |
| **D** | Constitution Alignment | Conflicts with MUST principles; missing mandated sections. Per-principle status: `ALIGNED` or `VIOLATION` (auto-CRITICAL) |
| **E** | Phase Separation | Per [phase-separation-rules.md](../iikit-core/references/phase-separation-rules.md) — tech in constitution, implementation in spec, governance in plan |
| **F** | Coverage Gaps | Requirements with zero tasks; tasks with no mapped requirement; non-functional requirements absent from tasks; requirements unreferenced in plan.md. Scan plan.md for each FR-xxx/SC-xxx ID; collect contextual refs (KDD-x, section headers) where found |
| **G** | Inconsistency | Terminology drift; entities in plan but not spec; conflicting requirements |
| **G2** | Prose Ranges | Patterns like "TS-XXX through TS-XXX" in tasks.md → flag MEDIUM: "Prose range detected — intermediate IDs not traceable. Use explicit comma-separated list." |
| **H** | Feature Traceability | When `FEATURE_DIR/tests/features/` exists — see H1–H3 below |

**H1. Untested requirements** (HIGH): For each FR-XXX/SC-XXX in spec.md, verify at least one `.feature` file carries a matching `@FR-XXX`/`@SC-XXX` tag. Flag unmatched IDs.

**H2. Orphaned tags** (MEDIUM): For each `@FR-XXX`/`@SC-XXX` tag in `.feature` files, verify the ID exists in spec.md. Flag tags referencing non-existent IDs.

**H3. Step definition coverage** (optional): If `tests/step_definitions/` exists, run:
- Bash: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/verify-steps.sh --json "FEATURE_DIR/tests/features" "FEATURE_DIR/plan.md"`

`BLOCKED` → report undefined steps (HIGH). `DEGRADED` → note in report only.

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

1. **Compute**: `score = max(0, round(100 - (critical×20 + high×5 + medium×2 + low×0.5)))`.
2. **Read** `.specify/score-history.json` (initialize `{}` if missing).
3. **Append** entry keyed by feature directory name (e.g. `001-user-auth`):
   `{ "timestamp": "<ISO-8601 UTC>", "score": <n>, "coverage_pct": <n>, "critical": <n>, "high": <n>, "medium": <n>, "low": <n>, "total_findings": <n> }`
4. **Write** updated object back to `.specify/score-history.json`.
5. **Trend**: compare new score to previous entry — `↑ improving` / `↓ declining` / `→ stable` (or stable if no prior entry).
6. **Display**: `Health Score: <score>/100 (<trend>)` in console and `analysis.md`.
7. **Include** full `score_history` array for the current feature under the **Score History** table in `analysis.md`.

### 6. Next Actions

- CRITICAL issues: recommend resolving before `/iikit-07-implement`
- LOW/MEDIUM only: may proceed with improvement suggestions

### 7. Offer Remediation

Ask: "Suggest concrete remediation edits for the top N issues?" Do NOT apply automatically.

## Operating Principles

- Minimal high-signal tokens, progressive disclosure, limit to 50 findings
- Never modify files, never hallucinate missing sections
- Prioritize constitution violations, use specific examples over exhaustive rules
- Report zero issues gracefully with coverage statistics

## Commit, Dashboard & Next Steps

Run post-phase to commit, refresh dashboard, and compute next step in a single call:

- Bash: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/post-phase.sh --phase 06 --commit-files "specs/*/analysis.md,.specify/score-history.json" --commit-msg "analyze: <feature-short-name> consistency report"`
- Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/post-phase.ps1 -Phase 06 -CommitFiles "specs/*/analysis.md,.specify/score-history.json" -CommitMsg "analyze: <feature-short-name> consistency report"`

Parse `next_step` from JSON. Present per [model-recommendations.md](../iikit-core/references/model-recommendations.md):
```
Analysis complete!
Next: [/clear → ] <next_step> (model: <tier>)
[- <alt_step> — <reason> (model: <tier>)]
- Dashboard: file://$(pwd)/.specify/dashboard.html
```
