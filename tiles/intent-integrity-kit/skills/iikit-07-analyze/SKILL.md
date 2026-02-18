---
name: iikit-07-analyze
description: >-
  Validate cross-artifact consistency — checks that every spec requirement traces to tasks, plan tech stack matches task file paths, and constitution principles are satisfied across all artifacts.
  Use when running a consistency check, verifying requirements traceability, detecting conflicts between design docs, or auditing alignment before implementation begins.
license: MIT
metadata:
  version: "1.6.7"
---

# Intent Integrity Kit Analyze

Non-destructive cross-artifact consistency analysis across spec.md, plan.md, and tasks.md.

## Operating Constraints

- **READ-ONLY** (exception: writes `analysis.md`). Never modify spec, plan, or task files.
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
- Constitution rule set

### 3. Detection Passes (limit 50 findings)

**A. Duplication**: near-duplicate requirements -> consolidate
**B. Ambiguity**: vague terms (fast, scalable, secure) without measurable criteria; unresolved placeholders
**C. Underspecification**: requirements missing objects/outcomes; stories without acceptance criteria; tasks referencing undefined components
**D. Constitution Alignment**: conflicts with MUST principles; missing mandated sections
**E. Phase Separation Violations**: per [phase-separation-rules.md](../iikit-core/references/phase-separation-rules.md) — tech in constitution, implementation in spec, governance in plan
**F. Coverage Gaps**: requirements with zero tasks; tasks with no mapped requirement; non-functional requirements not in tasks
**G. Inconsistency**: terminology drift; entities in plan but not spec; conflicting requirements

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

**Coverage Summary**: requirement key -> has task? -> task IDs
**Phase Separation Violations**: artifact, line, violation, severity
**Metrics**: total requirements, total tasks, coverage %, ambiguity count, critical issues
```

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

- CRITICAL issues: resolve, then re-run `/iikit-07-analyze`
- No CRITICAL: suggest the user run `/clear` before `/iikit-08-implement` — implementation is the heaviest skill and benefits from maximum context budget. All state is preserved on disk.
