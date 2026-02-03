# Intent Integrity Kit Phase Separation Guide

This document clarifies what belongs in each phase of the intent-integrity-kit workflow.

## Phase Overview

```
Constitution → Specify → Plan → Tasks → Implement
(governance)   (what)    (how)  (work)  (execute)
```

---

## 1. Constitution (`/iikit-00-constitution`)

**Purpose**: Define project governance principles and development guidelines.

### MUST Contain
- **High-level principles** (technology-agnostic)
  - "All code must have test coverage"
  - "All features must be accessible via CLI"
  - "Start simple, avoid over-engineering"
- **Quality standards** (conceptual)
  - "Minimum 80% test coverage target"
  - "Code must be reviewed before merge"
- **Governance rules**
  - Amendment procedures
  - Versioning policy
  - Compliance review expectations

### MUST NOT Contain
- **Technology stack** ❌
  - "Use Python 3.11" → belongs in Plan
  - "Use Click for CLI" → belongs in Plan
  - "Use SQLite for storage" → belongs in Plan
- **Implementation details** ❌
  - Specific frameworks or libraries
  - API designs
  - Data models
  - File paths or code structure

### Example (Correct)
```markdown
### I. Test Coverage
All features must have comprehensive test coverage before being considered complete.
- Every public function must have associated unit tests
- Integration tests required for critical paths
- Minimum 80% code coverage target
```

### Example (Incorrect - Tech Stack)
```markdown
## Development Standards
**Technology Stack:**
- Language: Python 3.11+  ← WRONG: belongs in plan
- CLI Framework: Click    ← WRONG: belongs in plan
- Storage: SQLite         ← WRONG: belongs in plan
```

---

## 2. Specify (`/iikit-01-specify`)

**Purpose**: Define WHAT users need and WHY (requirements, not implementation).

### MUST Contain
- **User stories** with priorities (P1, P2, P3)
- **Functional requirements** (what the system must do)
- **Success criteria** (technology-agnostic, measurable)
- **Key entities** (conceptual, not implementation)
- **Edge cases** and assumptions

### MUST NOT Contain
- **Technology choices** ❌
  - "Use REST API" → belongs in Plan
  - "Store in PostgreSQL" → belongs in Plan
- **Implementation details** ❌
  - API endpoints
  - Database schemas
  - Code structure
- **Technical metrics** ❌
  - "API response under 200ms" → use "Users see results instantly"
  - "Database handles 1000 TPS" → use user-facing metric

### Example (Correct)
```markdown
**SC-001**: Users can add a task and see it in the list within 1 second
**SC-002**: System supports 1000 concurrent users without degradation
```

### Example (Incorrect - Tech Details)
```markdown
**SC-001**: REST API returns 200 OK within 200ms  ← WRONG
**SC-002**: SQLite database handles 1000 TPS      ← WRONG
```

---

## 3. Plan (`/iikit-03-plan`)

**Purpose**: Define HOW to implement (technology choices, architecture).

### MUST Contain
- **Technical Context** (THIS IS WHERE TECH STACK GOES)
  - Language/Version: Python 3.11
  - Primary Dependencies: Click, SQLAlchemy
  - Storage: SQLite
  - Testing: pytest
- **Constitution Check** (validate tech choices against principles)
- **Project Structure** (directories, file organization)
- **Research findings** (technology decisions and rationale)
- **Data Model** (database schema, entity relationships)
- **API Contracts** (OpenAPI specs, GraphQL schemas)

### Example (Correct)
```markdown
## Technical Context

**Language/Version**: Python 3.11
**Primary Dependencies**: Click, SQLAlchemy
**Storage**: SQLite
**Testing**: pytest
**Target Platform**: Linux/macOS CLI
```

---

## 4. Tasks (`/iikit-05-tasks`)

**Purpose**: Break down the plan into actionable work items.

### MUST Contain
- **Task IDs** with proper format: `T001`, `T002`
- **Parallel markers** `[P]` for independent tasks
- **User story labels** `[US1]`, `[US2]` for traceability
- **File paths** for each task
- **Dependencies** between tasks
- **Phase organization** (Setup → Foundation → User Stories → Polish)

---

## Quick Reference Table

| Content Type | Constitution | Specify | Plan | Tasks |
|--------------|--------------|---------|------|-------|
| Principles/governance | ✅ | ❌ | ❌ | ❌ |
| User stories | ❌ | ✅ | ❌ | ❌ |
| Requirements | ❌ | ✅ | ❌ | ❌ |
| Success criteria | ❌ | ✅ | ❌ | ❌ |
| Technology stack | ❌ | ❌ | ✅ | ❌ |
| Architecture | ❌ | ❌ | ✅ | ❌ |
| Data models | ❌ | ❌ | ✅ | ❌ |
| API contracts | ❌ | ❌ | ✅ | ❌ |
| Task breakdown | ❌ | ❌ | ❌ | ✅ |
| File paths | ❌ | ❌ | ✅ | ✅ |

---

## Common Mistakes

### 1. Tech Stack in Constitution
❌ Wrong:
```markdown
## Development Standards
- Language: Python 3.11+
- Framework: Click
```

✅ Correct: Move to plan.md Technical Context

### 2. Implementation Details in Spec
❌ Wrong:
```markdown
**FR-005**: System MUST persist to SQLite database
```

✅ Correct:
```markdown
**FR-005**: System MUST persist all tasks to storage that survives restarts
```

### 3. Technical Metrics in Success Criteria
❌ Wrong:
```markdown
**SC-001**: API response time under 200ms
```

✅ Correct:
```markdown
**SC-001**: Users see results instantly (within 1 second)
```
