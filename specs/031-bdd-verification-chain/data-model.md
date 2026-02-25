# Data Model: BDD Verification Chain

## Entities

### Feature File

A standard Gherkin `.feature` file containing executable test specifications.

**Location**: `specs/NNN-feature/tests/features/*.feature`

**Attributes**:
- Filename (agent-chosen, descriptive)
- Feature name (Gherkin `Feature:` keyword)
- Scenarios (list of `Scenario:`, `Scenario Outline:`, with optional `Background:` and `Rule:`)
- Tags (`@TS-XXX`, `@FR-XXX`, `@US-XXX`, `@P1`-`@P3`, `@acceptance`/`@contract`/`@validation`)

**States**: Generated (by testify) → Hashed (by testify-tdd.sh) → Immutable (during implement)

### Step Definition

Glue code binding Gherkin steps to application calls.

**Location**: `specs/NNN-feature/tests/step_definitions/*`

**Attributes**:
- Step pattern (regex or cucumber expression matching a Given/When/Then line)
- Function body (the implementation)
- Language (matches project tech stack)

**States**: Undefined → Written (by implement) → Verified (by verify-steps.sh + verify-step-quality.sh)

### Assertion Hash

Integrity fingerprint of all step lines across all `.feature` files.

**Location**:
- Primary: `specs/NNN-feature/context.json` (`.testify.assertion_hash`)
- Backup: Git notes at `refs/notes/testify`

**Attributes**:
- `assertion_hash`: SHA-256 hex string (64 chars)
- `generated_at`: ISO 8601 UTC timestamp
- `features_dir`: relative path to `tests/features/`
- `file_count`: number of `.feature` files included in hash

**Computation**:
1. Glob `tests/features/*.feature`, sort by filename
2. For each file: extract lines matching `^\s*(Given|When|Then|And|But) `
3. Normalize: strip leading whitespace, collapse internal whitespace
4. Concatenate all extracted lines
5. SHA-256 hash the result

### BDD Framework

The language-specific test runner detected from plan.md.

**Attributes**:
- Name (e.g., pytest-bdd, @cucumber/cucumber, godog)
- Language (e.g., Python, JavaScript, Go)
- Dry-run command
- Strict mode mechanism
- Install command

**States**: Unknown → Detected (from plan.md) → Installed (by setup-bdd.sh) → Verified (by verify-steps.sh)

## State Transitions

```
testify generates .feature files
         │
         ▼
testify-tdd.sh computes + stores hash
         │
         ├──── context.json updated
         └──── git note stored (post-commit)
                  │
                  ▼
implement writes step definitions
         │
         ├──── verify-steps.sh: all steps defined? (PASS/BLOCKED)
         ├──── run tests: RED expected
         ├──── write production code
         ├──── run tests: GREEN expected
         └──── verify-step-quality.sh: assertions meaningful? (PASS/BLOCKED)
                  │
                  ▼
pre-commit-hook checks .feature hash
         │
         ├──── Hash matches → commit allowed
         └──── Hash mismatch → commit BLOCKED
```

## context.json Schema (testify section)

```json
{
  "testify": {
    "assertion_hash": "a1b2c3d4...",
    "generated_at": "2026-02-21T15:30:00Z",
    "features_dir": "tests/features",
    "file_count": 3
  }
}
```
