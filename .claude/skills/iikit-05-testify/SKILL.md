---
name: iikit-05-testify
description: >-
  Generate Gherkin .feature files from requirements before implementation — produces executable BDD scenarios with traceability tags, computes assertion integrity hashes, and locks acceptance criteria for test-driven development.
  Use when writing tests first, doing TDD, creating test cases from a spec, locking acceptance criteria, or setting up red-green-refactor with hash-verified assertions.
license: MIT
metadata:
  version: "1.7.0"
---

# Intent Integrity Kit Testify

Generate executable Gherkin `.feature` files from requirement artifacts before implementation. Enables TDD by creating hash-locked BDD scenarios that serve as acceptance criteria.

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

1. Run: `bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --phase 05 --json`
   Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/check-prerequisites.ps1 -Phase 05 -Json`
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

- **Required**: `spec.md` (acceptance scenarios), `plan.md` (API contracts, tech stack)
- **Optional**: `data-model.md` (validation rules)

### 2. Generate Gherkin Feature Files

Create `.feature` files in `FEATURE_DIR/tests/features/`:

**Output directory**: `FEATURE_DIR/tests/features/` (create if it does not exist)

**File organization**: Generate one `.feature` file per user story or logical grouping. Use descriptive filenames (e.g., `login.feature`, `user-management.feature`).

#### 2.1 Gherkin Tag Conventions

Every scenario MUST include traceability tags:
- `@TS-XXX` — test spec ID (sequential, unique across all .feature files)
- `@FR-XXX` — functional requirement from spec.md
- `@US-XXX` — user story reference
- `@P1` / `@P2` / `@P3` — priority level
- `@acceptance` / `@contract` / `@validation` — test type

Feature-level tags for shared metadata:
- `@US-XXX` on the Feature line for the parent user story

#### 2.2 Transformation Rules

**From spec.md — Acceptance Tests**: For each Given/When/Then scenario, generate a Gherkin scenario.

For transformation examples, advanced constructs (Background, Scenario Outline, Rule), and syntax validation rules, see [gherkin-reference.md](references/gherkin-reference.md).

### 3. Add DO NOT MODIFY Markers

Add an HTML comment at the top of each `.feature` file:
```gherkin
# DO NOT MODIFY SCENARIOS
# These .feature files define expected behavior derived from requirements.
# During implementation:
#   - Write step definitions to match these scenarios
#   - Fix code to pass tests, don't modify .feature files
#   - If requirements change, re-run /iikit-05-testify
```

### 4. Idempotency

If `tests/features/` already contains `.feature` files:
- Preserve existing scenario tags (TS-XXX) where the source scenario is unchanged
- Add new scenarios for new requirements
- Mark removed scenarios as deprecated (comment out with `# DEPRECATED:`)
- Show diff summary of changes

### 5. Store Assertion Integrity Hash

**CRITICAL**: Store SHA256 hash of assertion content in both locations:

```bash
# Context.json (auto-derived from features directory path)
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh store-hash "FEATURE_DIR/tests/features"

# Git note (tamper-resistant backup — uses first .feature file for note attachment)
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/testify-tdd.sh store-git-note "FEATURE_DIR/tests/features"
```

**Windows (PowerShell):**
```powershell
pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/testify-tdd.ps1 store-hash "FEATURE_DIR/tests/features"
pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/testify-tdd.ps1 store-git-note "FEATURE_DIR/tests/features"
```

The implement skill verifies this hash before proceeding, blocking if `.feature` file assertions were tampered with.

### 6. Report

Output: TDD determination, scenario counts by source (acceptance/contract/validation), output directory path, number of `.feature` files generated, hash status (LOCKED).

## Error Handling

| Condition | Response |
|-----------|----------|
| No constitution | ERROR: Run /iikit-00-constitution |
| TDD forbidden | ERROR with evidence |
| No plan.md | ERROR: Run /iikit-03-plan |
| No spec.md | ERROR: Run /iikit-01-specify |
| No acceptance scenarios | ERROR: Run /iikit-02-clarify |
| .feature syntax error | FIX: Auto-correct and report |

## Next Steps

You MUST read [model-recommendations.md](../iikit-core/references/model-recommendations.md), check the expiration date (refresh via web search if expired), detect the agent via env vars, and include a model switch tip in the output below if the next phase needs a different model tier.

```
Feature files generated!
- /iikit-06-tasks - Generate task breakdown (tasks can now reference .feature scenarios)
Tip: <model switch suggestion if tier mismatch, omit if already on the right model>
```
