---
name: iikit-05-testify
description: Generate test specifications from requirements before implementation (TDD support)
---

# Intent Integrity Kit Testify

Generate test specifications from requirement artifacts before implementation begins. This skill enables Test-Driven Development (TDD) by creating test specs that serve as acceptance criteria for the implementation phase.

## User Input

```text
$ARGUMENTS
```

This skill accepts **no user input parameters** - it reads artifacts automatically (FR-013).

## Constitution Loading (REQUIRED)

Before ANY action, load and analyze the project constitution for TDD requirements:

1. Read constitution:
   ```bash
   cat CONSTITUTION.md 2>/dev/null || echo "NO_CONSTITUTION"
   ```

2. If file doesn't exist:
   ```
   ERROR: Project constitution not found at CONSTITUTION.md

   Cannot proceed without constitution.
   Run: /iikit-00-constitution
   ```

3. **TDD Assessment** - Analyze constitution for TDD indicators:

   **Strong indicators (high confidence)**:
   - "TDD", "test-first", "red-green-refactor", "write tests before"
   - Combined with MUST, REQUIRED, NON-NEGOTIABLE -> **mandatory**

   **Moderate indicators (medium confidence)**:
   - "test-driven", "tests required before code", "tests before implementation"
   - Combined with MUST, REQUIRED -> **mandatory**

   **Implicit indicators (low confidence)**:
   - "quality gates", "coverage requirements", "test coverage"
   - Combined with SHOULD -> **optional**

   **Prohibition indicators**:
   - "test-after", "integration tests only", "no unit tests required"
   - Combined with MUST, REQUIRED -> **forbidden**

   **No indicators**:
   - No TDD-related terms found -> **optional** (high confidence)

4. **Output TDD Assessment**:
   ```
   +-----------------------------------------------------+
   |  TDD ASSESSMENT                                     |
   +-----------------------------------------------------+
   |  Determination: [mandatory | optional | forbidden]  |
   |  Confidence:    [high | medium | low]               |
   |  Evidence:      "[quoted constitutional text]"      |
   |  Reasoning:     [explanation]                       |
   +-----------------------------------------------------+
   ```

5. **If determination is "forbidden"**:
   ```
   ERROR: Constitution prohibits test-first development.

   Evidence: "[quoted text]"

   Testify cannot proceed. The constitution explicitly requires test-after
   or prohibits TDD practices.
   ```

## Prerequisites Check

1. Run prerequisites check:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --json
   ```

2. Parse JSON for `FEATURE_DIR` and `AVAILABLE_DOCS`.

3. Verify required artifacts exist:
   - **plan.md** MUST exist (testify runs after plan)
   - **spec.md** MUST exist (source for acceptance tests)

4. If plan.md missing:
   ```
   ERROR: plan.md not found in feature directory.

   Testify requires a completed plan.
   Run: /iikit-03-plan
   ```

5. If spec.md missing:
   ```
   ERROR: spec.md not found in feature directory.

   Testify requires a completed specification.
   Run: /iikit-01-specify
   ```

6. **Checklist completion check** (soft gate):
   - If `FEATURE_DIR/checklists/` directory exists and contains `.md` files:
     - Parse all checklist files for `- [ ]` (unchecked) and `- [x]` (checked) items
     - If any unchecked items remain:
       ```
       WARNING: Checklists exist but are incomplete (X/Y items checked, Z%).
       Recommend running /iikit-04-checklist to resolve before proceeding.
       Continue anyway? [y/N]
       ```
     - If user declines, stop and suggest `/iikit-04-checklist`
   - If no checklists directory exists: proceed silently (checklists are optional)

## Acceptance Scenario Validation

Before generating tests, validate that spec.md has acceptance scenarios:

1. Search spec.md for acceptance scenario patterns:
   - "Given ... When ... Then"
   - "Acceptance Scenarios:"
   - "**Given**" / "**When**" / "**Then**"

2. If NO acceptance scenarios found:
   ```
   ERROR: spec.md has no acceptance scenarios.

   Test specifications require acceptance scenarios to derive tests from.
   Run: /iikit-02-clarify to add acceptance scenarios to the specification.
   ```

## Execution Flow

### 1. Load Source Artifacts

Read from FEATURE_DIR:
- **Required**: `spec.md` (acceptance scenarios, functional requirements)
- **Required**: `plan.md` (API contracts, technical decisions)
- **Optional**: `data-model.md` (entity constraints, validation rules)

### 2. Generate Test Specifications

Create `FEATURE_DIR/tests/test-specs.md` with the following structure:

#### 2.1 From spec.md - Acceptance Tests

For each acceptance scenario in spec.md:

1. Parse the Given/When/Then structure
2. Generate a test specification with:
   - **TS-NNN ID**: Sequential numbering (TS-001, TS-002, etc.)
   - **Source**: `spec.md:[User Story]:[scenario number]`
   - **Type**: `acceptance`
   - **Priority**: Match the user story priority (P1, P2, P3)
   - **Given/When/Then**: Copy from scenario
   - **Traceability**: Link to FR-XXX, SC-XXX, US-XXX-scenario-X

**Example transformation**:

Input (from spec.md):
```
### User Story 1 - Login (Priority: P1)

**Acceptance Scenarios**:
1. **Given** a registered user, **When** they enter valid credentials, **Then** they are logged in.
```

Output (in test-specs.md):
```markdown
### TS-001: Login with valid credentials

**Source**: spec.md:User Story 1:scenario-1
**Type**: acceptance
**Priority**: P1

**Given**: a registered user
**When**: they enter valid credentials
**Then**: they are logged in

**Traceability**: FR-001, US-001-scenario-1
```

#### 2.2 From plan.md - Contract Tests

For each API endpoint or interface defined in plan.md:

1. Extract endpoint definition
2. Generate contract test specification:
   - **Type**: `contract`
   - **Source**: `plan.md:[section]:[endpoint]`
   - **Given**: API is available
   - **When**: Request is made with valid/invalid parameters
   - **Then**: Response matches contract (status, schema, headers)

#### 2.3 From data-model.md - Validation Tests

For each entity with validation rules in data-model.md:

1. Extract validation constraints
2. Generate validation test specifications:
   - **Type**: `validation`
   - **Source**: `data-model.md:[entity]:[constraint]`
   - **Given**: Entity data
   - **When**: Validation is performed
   - **Then**: Constraint is enforced (or error returned)

### 3. Add DO NOT MODIFY Markers

Include clear markers in the generated test-specs.md:

```markdown
<!--
DO NOT MODIFY TEST ASSERTIONS

These test specifications define the expected behavior derived from requirements.
During implementation:
- Fix code to pass tests, don't modify test assertions
- Structural changes (file organization, naming) are acceptable with justification
- Logic changes to assertions require explicit justification and re-review

If requirements change, re-run /iikit-05-testify to regenerate test specs.
-->
```

### 4. Idempotency Support

If `tests/test-specs.md` already exists:

1. Parse existing test IDs (TS-NNN)
2. For each existing test, check if source requirement still exists
3. Preserve existing test IDs where source hasn't changed
4. Add new tests for new requirements
5. Mark removed requirements' tests as deprecated

Output semantic diff:
```
+-----------------------------------------------------+
|  TEST SPEC UPDATE                                   |
+-----------------------------------------------------+
|  Preserved: X tests (unchanged requirements)        |
|  Added:     Y tests (new requirements)              |
|  Removed:   Z tests (requirements removed)          |
+-----------------------------------------------------+
```

### 5. Create Output Directory

Create the tests directory if it doesn't exist:
```bash
mkdir -p FEATURE_DIR/tests
```

### 6. Store Assertion Integrity Hash

**CRITICAL**: After writing test-specs.md, store a hash of the assertion content to prevent tampering.

**Store hash in BOTH locations** for defense in depth:

**Unix/macOS/Linux:**
```bash
# Store in context.json (auto-derived: FEATURE_DIR/context.json)
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh store-hash "FEATURE_DIR/tests/test-specs.md"

# Store as git note (tamper-resistant backup)
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh store-git-note "FEATURE_DIR/tests/test-specs.md"
```

**Windows (PowerShell):**
```powershell
# Store in context.json (auto-derived: FEATURE_DIR/context.json)
pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/testify-tdd.ps1 store-hash "FEATURE_DIR/tests/test-specs.md"

# Store as git note (tamper-resistant backup)
pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/testify-tdd.ps1 store-git-note "FEATURE_DIR/tests/test-specs.md"
```

This stores a SHA256 hash of all Given/When/Then assertion lines in two locations:
1. **FEATURE_DIR/context.json** - Primary storage per feature (path auto-derived from test-specs.md location — agent cannot override)
2. **Git note** - Tamper-resistant backup (requires git history rewrite to modify)

The implement skill will verify this hash before proceeding, blocking execution if assertions were tampered with.

### 7. Generate Summary Report

Output a clear report showing what was generated:

```
+-----------------------------------------------------+
|  TESTIFY COMPLETE                                   |
+-----------------------------------------------------+
|  TDD Assessment: [mandatory | optional]             |
|                                                     |
|  Test Specifications Generated:                     |
|    From spec.md:       X acceptance tests           |
|    From plan.md:       Y contract tests             |
|    From data-model.md: Z validation tests           |
|    -------------------------------------            |
|    Total:              N test specifications        |
|                                                     |
|  Output: FEATURE_DIR/tests/test-specs.md            |
|                                                     |
|  Assertion Integrity:                               |
|    Hash: [first 12 chars of hash]...                |
|    Status: LOCKED                                   |
+-----------------------------------------------------+
```

**Note**: The assertion hash ensures test integrity. If test-specs.md assertions are modified without re-running testify, the implement skill will detect the tampering and refuse to proceed.

## Output Format

Read [testspec-template.md](../iikit-core/templates/testspec-template.md) for the standard structure.

The generated `tests/test-specs.md` follows this template:

```markdown
# Test Specifications: [Feature Name]

**Generated**: [timestamp]
**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## TDD Assessment

**Determination**: [mandatory | optional | forbidden]
**Confidence**: [high | medium | low]
**Evidence**: [quoted constitutional statements or "No TDD indicators found"]
**Reasoning**: [explanation of determination]

---

<!--
DO NOT MODIFY TEST ASSERTIONS
[full marker text]
-->

## From spec.md (Acceptance Tests)

### TS-001: [Test Name]
[test spec content]

---

## From plan.md (Contract Tests)

### TS-XXX: [Test Name]
[test spec content]

---

## From data-model.md (Validation Tests)

### TS-XXX: [Test Name]
[test spec content]

---

## Summary

| Source | Count | Types |
|--------|-------|-------|
| spec.md | X | acceptance |
| plan.md | Y | contract |
| data-model.md | Z | validation |
| **Total** | **N** | |
```

## Error Handling

| Condition | Detection | Response |
|-----------|-----------|----------|
| No constitution | File not found | ERROR with "Run /iikit-00-constitution" |
| TDD forbidden | Prohibition indicators found | ERROR with quoted evidence |
| No plan.md | File not found | ERROR with "Run /iikit-03-plan" |
| No spec.md | File not found | ERROR with "Run /iikit-01-specify" |
| No acceptance scenarios | Pattern not found in spec.md | ERROR with "Run /iikit-02-clarify" |

## Next Steps

After generating test specifications:

1. **Required**: Run `/iikit-06-tasks` to generate tasks that reference the test specs

Suggest to user:
```
Test specifications generated! Next steps:
- /iikit-06-tasks - Generate task breakdown (tasks can now reference test specs)
```

**Note**: When TDD is mandatory, `/iikit-08-implement` will verify test specs exist before proceeding.
