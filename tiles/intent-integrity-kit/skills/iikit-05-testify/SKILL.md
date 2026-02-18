---
name: iikit-05-testify
description: >-
  Generate test specifications from requirements before implementation — produces Given/When/Then test cases, computes assertion integrity hashes, and locks acceptance criteria for test-driven development.
  Use when writing tests first, doing TDD, creating test cases from a spec, locking acceptance criteria, or setting up red-green-refactor with hash-verified assertions.
license: MIT
---

# Intent Integrity Kit Testify

Generate test specifications from requirement artifacts before implementation. Enables TDD by creating hash-locked test specs that serve as acceptance criteria.

## User Input

```text
$ARGUMENTS
```

This skill accepts **no user input parameters** — it reads artifacts automatically.

## Constitution Loading

Load constitution per [constitution-loading.md](../iikit-core/references/constitution-loading.md) (basic mode), then perform TDD assessment:

**Scan for TDD indicators**:
- Strong (MUST/REQUIRED + "TDD", "test-first", "red-green-refactor") -> **mandatory**
- Moderate (MUST + "test-driven", "tests before code") -> **mandatory**
- Implicit (SHOULD + "quality gates", "coverage requirements") -> **optional**
- Prohibition (MUST + "test-after", "no unit tests") -> **forbidden** (ERROR, halt)
- None found -> **optional**

Report per [formatting-guide.md](../iikit-core/references/formatting-guide.md) (TDD Assessment section).

## Prerequisites Check

1. Run: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --json`
2. Parse for `FEATURE_DIR` and `AVAILABLE_DOCS`. Require **plan.md** and **spec.md** (ERROR if missing).
3. If JSON contains `needs_selection: true`: present the `features` array as a numbered table (name and stage columns). Follow the options presentation pattern in [conversation-guide.md](../iikit-core/references/conversation-guide.md). After user selects, run:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selection>
   ```
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/set-active-feature.ps1 -Json <selection>`

   Then re-run the prerequisites check from step 1.
4. Checklist gate per [checklist-gate.md](../iikit-core/references/checklist-gate.md).

## Acceptance Scenario Validation

Search spec.md for Given/When/Then patterns. If none found: ERROR with `Run: /iikit-02-clarify`.

## Execution Flow

### 1. Load Artifacts

- **Required**: `spec.md` (acceptance scenarios), `plan.md` (API contracts)
- **Optional**: `data-model.md` (validation rules)

### 2. Generate Test Specifications

Create `FEATURE_DIR/tests/test-specs.md`:

**From spec.md — Acceptance Tests**: For each Given/When/Then scenario, generate a test spec entry.

Example transformation — input (spec.md):
```
### User Story 1 - Login (Priority: P1)
**Acceptance Scenarios**:
1. **Given** a registered user, **When** they enter valid credentials, **Then** they are logged in.
```

Output (test-specs.md):
```markdown
### TS-001: Login with valid credentials
**Source**: spec.md:User Story 1:scenario-1
**Type**: acceptance | **Priority**: P1
**Given**: a registered user
**When**: they enter valid credentials
**Then**: they are logged in
**Traceability**: FR-001, US-001-scenario-1
```

**From plan.md — Contract Tests**: For each API endpoint, generate contract tests (request/response validation).

**From data-model.md — Validation Tests**: For each entity constraint, generate validation tests.

Use [testspec-template.md](../iikit-core/templates/testspec-template.md) for output format.

### 3. Add DO NOT MODIFY Markers

Include HTML comment: assertions define expected behavior from requirements. Fix code to pass tests, don't modify assertions. If requirements change, re-run `/iikit-05-testify`.

### 4. Idempotency

If test-specs.md exists: preserve existing test IDs where source unchanged, add new, mark removed as deprecated. Show diff summary.

### 5. Store Assertion Integrity Hash

**CRITICAL**: Store SHA256 hash of assertion content in both locations:

```bash
# Context.json (auto-derived from test-specs.md path)
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh store-hash "FEATURE_DIR/tests/test-specs.md"

# Git note (tamper-resistant backup)
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh store-git-note "FEATURE_DIR/tests/test-specs.md"
```

**Windows (PowerShell):**
```powershell
pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/testify-tdd.ps1 store-hash "FEATURE_DIR/tests/test-specs.md"
pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/testify-tdd.ps1 store-git-note "FEATURE_DIR/tests/test-specs.md"
```

The implement skill verifies this hash before proceeding, blocking if assertions were tampered with.

### 6. Report

Output: TDD determination, test counts by source (acceptance/contract/validation), output path, hash status (LOCKED).

## Error Handling

| Condition | Response |
|-----------|----------|
| No constitution | ERROR: Run /iikit-00-constitution |
| TDD forbidden | ERROR with evidence |
| No plan.md | ERROR: Run /iikit-03-plan |
| No spec.md | ERROR: Run /iikit-01-specify |
| No acceptance scenarios | ERROR: Run /iikit-02-clarify |

## Next Steps

```
Test specifications generated!
- /iikit-06-tasks - Generate task breakdown (tasks can now reference test specs)
```
