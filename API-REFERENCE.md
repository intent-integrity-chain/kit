# Intent Integrity Kit Skills API Reference

**Version**: 1.0.0 | **Last Updated**: 2026-02-02

## Quick Reference

| # | Skill | Command | Input | Output | Prerequisites |
|---|-------|---------|-------|--------|---------------|
| - | Core | `/iikit-core` | Subcommand: init, status, help | Project structure, status report | None |
| 0 | Constitution | `/iikit-00-constitution` | Governance principles (optional) | `CONSTITUTION.md` | None |
| 1 | Specify | `/iikit-01-specify` | Feature description (required) | `specs/NNN-feature/spec.md` | Constitution (warn if missing) |
| 2 | Clarify | `/iikit-02-clarify` | None (reads spec) | Updated `spec.md` with clarifications | spec.md |
| 3 | Plan | `/iikit-03-plan` | None (reads spec) | `plan.md`, `research.md`, `data-model.md`, `contracts/` | constitution.md, spec.md |
| 4 | Checklist | `/iikit-04-checklist` | Domain focus (optional) | `checklists/*.md` | spec.md |
| 5 | Testify | `/iikit-05-testify` | None (reads artifacts) | `tests/test-specs.md` | constitution.md, spec.md, plan.md |
| 6 | Tasks | `/iikit-06-tasks` | None (reads plan) | `tasks.md` | plan.md |
| 7 | Analyze | `/iikit-07-analyze` | None (reads all) | Console report | spec.md, plan.md, tasks.md |
| 8 | Implement | `/iikit-08-implement` | None (reads tasks) | Implementation code | tasks.md, checklists (100%) |
| 9 | Tasks to Issues | `/iikit-09-taskstoissues` | None (reads tasks) | GitHub Issues | tasks.md, GitHub remote |

---

## Dependency Graph

```
┌──────────────────┐
│  00-constitution │ ◄── Optional but recommended first
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│   01-specify     │ ◄── REQUIRED: Feature description
└────────┬─────────┘
         │
         ├────────────────────┐
         ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│   02-clarify     │  │   04-checklist   │
│   (optional)     │  │   (optional)     │
└────────┬─────────┘  └──────────────────┘
         │
         ▼
┌──────────────────┐
│    03-plan       │ ◄── REQUIRES: constitution.md
└────────┬─────────┘
         │
         ├────────────────────┐
         ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│   05-testify     │  │   04-checklist   │
│ (optional/TDD)   │  │   (if not done)  │
└────────┬─────────┘  └──────────────────┘
         │
         ▼
┌──────────────────┐
│    06-tasks      │
└────────┬─────────┘
         │
         ├────────────────────┐
         ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│   07-analyze     │  │ 09-taskstoissues │
│   (optional)     │  │   (optional)     │
└────────┬─────────┘  └──────────────────┘
         │
         ▼
┌──────────────────┐
│   08-implement   │ ◄── REQUIRES: checklists 100%
└──────────────────┘
```

---

## Skill Details

### Core

**Purpose**: Initialize project, check status, display workflow help

**Command**: `/iikit-core [subcommand]`

**Subcommands**:

| Subcommand | Purpose |
|------------|---------|
| `init` | Initialize IIKit in current directory |
| `status` | Show project and feature status |
| `help` | Display workflow phases and commands |

If no subcommand provided, shows help.

**init Output**:
- `.specify/` directory
- `specs/` directory
- Initializes git if needed

**status Output**:
```
╭─────────────────────────────────────────────────────╮
│  IIKIT STATUS                                       │
├─────────────────────────────────────────────────────┤
│  Constitution:  [exists/missing]                    │
│  Current Feature: NNN-feature-name                  │
│  Artifacts: spec.md ✓, plan.md ✓, tasks.md ✗       │
│  Next Step: /iikit-06-tasks                         │
╰─────────────────────────────────────────────────────╯
```

**Prerequisites**: None

---

### 00 - Constitution

**Purpose**: Create project governance principles

**Command**: `/iikit-00-constitution [governance description]`

**Input**:
- Optional: Natural language description of project principles
- If empty: Uses template, infers from existing repo context

**Output**:
- `CONSTITUTION.md`

**Prerequisites**: None

**Validation**:
- Phase separation: No technology-specific content allowed
- Auto-fixes: Replaces tech references with governance statements

**Example**:
```
/iikit-00-constitution We use TDD, all code must have tests before implementation
```

---

### 01 - Specify

**Purpose**: Create feature specification from natural language

**Command**: `/iikit-01-specify <feature description>`

**Input** (REQUIRED):
- Feature description in natural language
- Example: `Add user authentication with OAuth2 support`

**Output**:
- `specs/NNN-feature-name/spec.md`
- `specs/NNN-feature-name/checklists/requirements.md`
- Git branch: `NNN-feature-name` (optional)

**Prerequisites**:
- Constitution: Warns if missing, continues

**Validation**:
- Phase separation: No implementation details
- Maximum 3 `[NEEDS CLARIFICATION]` markers

**User Prompts**:
- Branch creation: `Create feature branch? [Y/n]`

---

### 02 - Clarify

**Purpose**: Resolve specification ambiguities

**Command**: `/iikit-02-clarify`

**Input**: None (reads from spec.md)

**Output**:
- Updated `spec.md` with clarifications section
- Maximum 5 questions asked

**Prerequisites**:
- `spec.md` must exist

**Behavior**:
- Presents one question at a time
- Provides recommended option for each question
- Records answers in `## Clarifications` section

---

### 03 - Plan

**Purpose**: Create technical implementation plan

**Command**: `/iikit-03-plan`

**Input**: None (reads spec.md, constitution.md)

**Output**:
- `plan.md` - Technical decisions
- `research.md` - Research findings, Tessl tiles
- `data-model.md` - Entity definitions
- `contracts/` - API specifications
- `quickstart.md` - Integration scenarios
- Updated `CLAUDE.md` with tech stack

**Prerequisites** (HARD GATE):
- `constitution.md` must exist
- `spec.md` must exist

**Validation**:
- Spec quality score (1-10)
- Constitution enforcement rules extracted
- Phase separation: No governance content

**Tessl Integration**:
- Searches for tiles matching tech stack
- Installs discovered tiles
- Documents in `research.md`

---

### 04 - Checklist

**Purpose**: Generate quality checklists for requirements

**Command**: `/iikit-04-checklist [domain focus]`

**Input**:
- Optional: Domain focus (UX, API, Security, etc.)
- If empty: Infers from spec/plan

**Output**:
- `checklists/[domain].md`

**Prerequisites**:
- `spec.md` must exist

**Key Concept**: "Unit Tests for English"
- Validates REQUIREMENTS quality, not implementation
- Each item checks completeness, clarity, consistency
- Items marked `[Gap]` trigger interactive resolution

**Item Format**:
```markdown
- [ ] CHK001 - Are visual hierarchy requirements defined? [Completeness, Spec SFR-1]
```

---

### 05 - Testify

**Purpose**: Generate test specifications (TDD support)

**Command**: `/iikit-05-testify`

**Input**: None (reads artifacts automatically)

**Output**:
- `tests/test-specs.md`
- Assertion hash stored in `.specify/context.json`
- Assertion hash stored as git note (backup)

**Prerequisites** (HARD GATE):
- `constitution.md` must exist
- `spec.md` must exist with acceptance scenarios
- `plan.md` must exist

**TDD Assessment**:
Analyzes constitution for TDD requirements:
- `mandatory`: Constitution requires TDD
- `optional`: No TDD requirement
- `forbidden`: Constitution prohibits TDD (skill halts)

**Test Types Generated**:
| Source | Type | Example |
|--------|------|---------|
| spec.md | Acceptance | User login scenarios |
| plan.md | Contract | API endpoint validation |
| data-model.md | Validation | Entity constraint checks |

**Tamper Protection**:
- SHA256 hash of all Given/When/Then lines
- Dual storage: context.json + git note
- Implementation skill verifies hash before proceeding

---

### 06 - Tasks

**Purpose**: Generate actionable task breakdown

**Command**: `/iikit-06-tasks`

**Input**: None (reads plan.md, spec.md)

**Output**:
- `tasks.md`

**Prerequisites**:
- `plan.md` must exist

**Task Format**:
```markdown
- [ ] T001 [P] [US1] Description with file path
```

Components:
- `T001`: Sequential ID
- `[P]`: Parallelizable (optional)
- `[US1]`: User story reference (for story phases)
- Description: Action with file path

**Phase Structure**:
1. Setup - Project initialization
2. Foundational - Blocking prerequisites
3. User Stories - Priority ordered (P1, P2, P3...)
4. Polish - Cross-cutting concerns

**Validation**:
- Circular dependency detection
- Orphan task detection
- Critical path analysis
- Phase boundary validation

---

### 07 - Analyze

**Purpose**: Validate cross-artifact consistency

**Command**: `/iikit-07-analyze`

**Input**: None (reads all artifacts)

**Output**:
- Console report (no files modified)
- Optional remediation plan

**Prerequisites** (HARD GATE):
- `constitution.md` must exist
- `spec.md` must exist
- `plan.md` must exist
- `tasks.md` must exist

**Detection Passes**:
- Duplication detection
- Ambiguity detection
- Underspecification
- Constitution alignment
- Phase separation violations
- Coverage gaps
- Inconsistency

**Severity Levels**:
| Level | Criteria |
|-------|----------|
| CRITICAL | Constitution violation, phase separation, zero coverage |
| HIGH | Duplicate/conflicting requirement, ambiguous security |
| MEDIUM | Terminology drift, missing coverage |
| LOW | Style improvements |

**Output**: READ-ONLY analysis, no files modified

---

### 08 - Implement

**Purpose**: Execute implementation plan

**Command**: `/iikit-08-implement`

**Input**: None (reads tasks.md)

**Output**:
- Implementation code
- Updated `tasks.md` with completion markers

**Prerequisites** (HARD GATES):
- `constitution.md` must exist
- `tasks.md` must exist
- All checklists must be 100% complete (prompts if not)
- If TDD mandatory: `tests/test-specs.md` must exist
- Assertion integrity verification (blocks on tamper)

**Pre-Implementation Validation**:
```
╭─────────────────────────────────────────────────────╮
│  IMPLEMENTATION READINESS                            │
├─────────────────────────────────────────────────────┤
│  Artifacts:        X/Y complete              [✓/✗]  │
│  Spec Coverage:    X% requirements → tasks   [✓/✗]  │
│  Plan Alignment:   [Aligned/X mismatches]    [✓/✗]  │
│  Constitution:     [Compliant/X violations]  [✓/✗]  │
│  Checklists:       X/Y at 100%               [✓/✗]  │
│  Dependencies:     [Valid/Circular detected] [✓/✗]  │
╰─────────────────────────────────────────────────────╯
```

**Tessl Integration**:
- Queries documentation tiles before implementing library code
- Invokes skill tiles when relevant
- Reports tile usage at completion

**Execution**:
- Phase-by-phase execution
- Respects task dependencies
- Marks completed tasks with `[x]`

---

### 09 - Tasks to Issues

**Purpose**: Export tasks to GitHub Issues

**Command**: `/iikit-09-taskstoissues`

**Input**: None (reads tasks.md)

**Output**:
- GitHub Issues created via `gh` CLI
- Cross-references between dependent issues

**Prerequisites**:
- `tasks.md` must exist
- Git remote must be GitHub URL
- `gh` CLI must be installed and authenticated

**Issue Format**:
```markdown
## Task Details
**Task ID**: T012
**Phase**: Phase 3: User Story 1
**User Story**: US1

## Description
[Task description]

## Dependencies
- Depends on: #[issue-number]
- Blocks: #[issue-number]
```

**Labels Created**:
- `iikit` - All intent-integrity-kit issues
- `phase-N` - Phase grouping
- `us-N` - User story grouping
- `parallel` - Parallelizable tasks

---

## Error Conditions

| Error | Skill(s) | Resolution |
|-------|----------|------------|
| `Constitution not found` | 03, 05, 07, 08 | Run `/iikit-00-constitution` |
| `spec.md not found` | 02, 03, 04, 05, 06, 07 | Run `/iikit-01-specify` |
| `plan.md not found` | 05, 06, 07, 08 | Run `/iikit-03-plan` |
| `tasks.md not found` | 07, 08, 09 | Run `/iikit-06-tasks` |
| `No acceptance scenarios` | 05 | Run `/iikit-02-clarify` |
| `TDD forbidden` | 05 | Constitution prohibits TDD |
| `Assertion integrity failed` | 08 | Restore test-specs.md or re-run `/iikit-05-testify` |
| `Checklists incomplete` | 08 | Complete checklists or confirm proceed |
| `Not a GitHub remote` | 09 | Only works with GitHub repositories |
| `gh CLI not installed` | 09 | Install GitHub CLI |

---

## Artifacts Summary

| Artifact | Created By | Used By | Location |
|----------|------------|---------|----------|
| constitution.md | 00 | All skills | `root (CONSTITUTION.md)` |
| spec.md | 01 | 02, 03, 04, 05, 06, 07 | `specs/NNN-feature/` |
| plan.md | 03 | 05, 06, 07, 08 | `specs/NNN-feature/` |
| research.md | 03 | 08 | `specs/NNN-feature/` |
| data-model.md | 03 | 05, 08 | `specs/NNN-feature/` |
| contracts/ | 03 | 08 | `specs/NNN-feature/` |
| quickstart.md | 03 | 08 | `specs/NNN-feature/` |
| checklists/*.md | 01, 04 | 08 | `specs/NNN-feature/checklists/` |
| tests/test-specs.md | 05 | 06, 08 | `specs/NNN-feature/tests/` |
| tasks.md | 06 | 07, 08, 09 | `specs/NNN-feature/` |
| context.json | 05 | 08 | `.specify/` |

---

## Platform Support

All skills support both Unix/macOS/Linux and Windows:

| Component | Unix/macOS | Windows |
|-----------|------------|---------|
| Scripts | `.claude/skills/iikit-core/scripts/bash/*.sh` | `.claude/skills/iikit-core/scripts/powershell/*.ps1` |
| Detection | `command -v` | `Get-Command` |
| Tessl | `tessl` CLI | `tessl` CLI |
| GitHub | `gh` CLI | `gh` CLI |

Skills automatically detect platform and use appropriate scripts.

---

## Tessl Integration

When Tessl is installed, skills integrate automatically:

| Skill | Tessl Usage |
|-------|-------------|
| 03-plan | Search/install tiles for tech stack |
| 06-tasks | Query framework conventions |
| 08-implement | Query docs before implementing, invoke skill tiles |

If Tessl is not installed, skills continue without tile support.
