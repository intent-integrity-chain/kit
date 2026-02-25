# Test Specifications: BDD Verification Chain

**Generated**: 2026-02-21
**Feature**: `spec.md` | **Plan**: `plan.md`

## TDD Assessment

**Determination**: optional
**Confidence**: high
**Evidence**: No TDD indicators found in constitution
**Reasoning**: No MUST/SHOULD + TDD patterns found. Generating test specs voluntarily for a feature that builds test verification infrastructure.

---

<!--
DO NOT MODIFY TEST ASSERTIONS

These test specifications define the expected behavior derived from requirements.
During implementation:
- Fix code to pass tests, don't modify test assertions
- Structural changes (file organization, naming) are acceptable with justification
- Logic changes to assertions require explicit justification and re-review

If requirements change, re-run /iikit-05-testify to regenerate test specs.
-->

## From spec.md (Acceptance Tests)

### TS-001: Testify generates .feature files in correct directory

**Source**: spec.md:User Story 1:scenario-1
**Type**: acceptance | **Priority**: P1

**Given**: a feature with a completed spec.md
**When**: testify runs
**Then**: one or more .feature files are generated in tests/features/

**Traceability**: FR-001, US-001-scenario-1

---

### TS-002: Feature files include traceability tags for all requirements

**Source**: spec.md:User Story 1:scenario-2
**Type**: acceptance | **Priority**: P1

**Given**: a spec with multiple user stories and requirements
**When**: testify runs
**Then**: every functional requirement (FR-XXX) and user story (US-XXX) is traceable via Gherkin tags in the generated files

**Traceability**: FR-002, SC-001, US-001-scenario-2

---

### TS-003: Scenario Outline used for parameterized scenarios

**Source**: spec.md:User Story 1:scenario-3
**Type**: acceptance | **Priority**: P1

**Given**: a spec with parameterized acceptance scenarios
**When**: testify runs
**Then**: Scenario Outline with Examples tables are used where scenarios differ only by data

**Traceability**: FR-016, US-001-scenario-3

---

### TS-004: Background used for shared preconditions

**Source**: spec.md:User Story 1:scenario-4
**Type**: acceptance | **Priority**: P1

**Given**: a spec where 3+ scenarios share setup preconditions
**When**: testify runs
**Then**: Background is used to avoid duplication

**Traceability**: FR-016, US-001-scenario-4

---

### TS-005: Rule blocks used for business rule grouping

**Source**: spec.md:User Story 1:scenario-5
**Type**: acceptance | **Priority**: P1

**Given**: a spec with distinct business rule groupings
**When**: testify runs
**Then**: Rule blocks group related scenarios

**Traceability**: FR-016, US-001-scenario-5

---

### TS-006: Combined hash stored after feature file generation

**Source**: spec.md:User Story 2:scenario-1
**Type**: acceptance | **Priority**: P1

**Given**: generated .feature files
**When**: testify completes
**Then**: a combined SHA-256 hash of all assertion lines is stored

**Traceability**: FR-004, US-002-scenario-1

---

### TS-007: Pre-commit hook blocks tampered feature files

**Source**: spec.md:User Story 2:scenario-2
**Type**: acceptance | **Priority**: P1

**Given**: a stored hash
**When**: a .feature file step line is modified
**Then**: the pre-commit hook detects the mismatch and blocks the commit

**Traceability**: FR-005, SC-004, US-002-scenario-2

---

### TS-008: Whitespace-only changes do not invalidate hash

**Source**: spec.md:User Story 2:scenario-3
**Type**: acceptance | **Priority**: P1

**Given**: a stored hash
**When**: only whitespace or comments change in .feature files
**Then**: the hash still validates (whitespace-normalized)

**Traceability**: FR-017, US-002-scenario-3

---

### TS-009: Hash computation uses sorted filename order

**Source**: spec.md:User Story 2:scenario-4
**Type**: acceptance | **Priority**: P1

**Given**: multiple .feature files
**When**: the hash is computed
**Then**: files are processed in sorted filename order for deterministic results

**Traceability**: FR-004, US-002-scenario-4

---

### TS-010: Step coverage reports matched steps

**Source**: spec.md:User Story 3:scenario-1
**Type**: acceptance | **Priority**: P1

**Given**: .feature files and a project with step definitions
**When**: step coverage is verified
**Then**: all steps with matching definitions are reported as matched

**Traceability**: FR-006, US-003-scenario-1

---

### TS-011: Undefined steps reported with location

**Source**: spec.md:User Story 3:scenario-2
**Type**: acceptance | **Priority**: P1

**Given**: .feature files with steps that have no step definitions
**When**: step coverage is verified
**Then**: each undefined step is reported with file and line number

**Traceability**: FR-006, US-003-scenario-2

---

### TS-012: Step coverage passes when all steps defined

**Source**: spec.md:User Story 3:scenario-3
**Type**: acceptance | **Priority**: P1

**Given**: all steps have matching definitions
**When**: step coverage is verified
**Then**: the verification passes with a count of total and matched steps

**Traceability**: FR-006, US-003-scenario-3

---

### TS-013: Step coverage fails on undefined steps

**Source**: spec.md:User Story 3:scenario-4
**Type**: acceptance | **Priority**: P1

**Given**: any undefined steps exist
**When**: step coverage is verified
**Then**: the verification fails with exit code non-zero

**Traceability**: FR-006, SC-002, US-003-scenario-4

---

### TS-014: Empty Then body detected as FAIL

**Source**: spec.md:User Story 4:scenario-1
**Type**: acceptance | **Priority**: P1

**Given**: a Then step definition with an empty body
**When**: quality is analyzed
**Then**: it is flagged as FAIL with issue "EMPTY_BODY"

**Traceability**: FR-007, US-004-scenario-1

---

### TS-015: Tautological assertion detected as FAIL

**Source**: spec.md:User Story 4:scenario-2
**Type**: acceptance | **Priority**: P1

**Given**: a Then step definition containing only assert True or equivalent tautology
**When**: quality is analyzed
**Then**: it is flagged as FAIL with issue "TAUTOLOGY"

**Traceability**: FR-007, SC-003, US-004-scenario-2

---

### TS-016: Missing assertion keywords detected as FAIL

**Source**: spec.md:User Story 4:scenario-3
**Type**: acceptance | **Priority**: P1

**Given**: a Then step definition with no assertion keywords
**When**: quality is analyzed
**Then**: it is flagged as FAIL with issue "NO_ASSERTION"

**Traceability**: FR-007, US-004-scenario-3

---

### TS-017: Empty When body detected as FAIL

**Source**: spec.md:User Story 4:scenario-4
**Type**: acceptance | **Priority**: P1

**Given**: a When step definition with an empty body
**When**: quality is analyzed
**Then**: it is flagged as FAIL with issue "EMPTY_BODY"

**Traceability**: FR-007, US-004-scenario-4

---

### TS-018: Meaningful assertions pass quality analysis

**Source**: spec.md:User Story 4:scenario-5
**Type**: acceptance | **Priority**: P1

**Given**: a Then step definition with meaningful assertions
**When**: quality is analyzed
**Then**: it passes quality analysis

**Traceability**: FR-007, US-004-scenario-5

---

### TS-019: AST-level parsing used for quality analysis

**Source**: spec.md:User Story 4:scenario-6
**Type**: acceptance | **Priority**: P1

**Given**: step definitions in any supported language
**When**: quality is analyzed
**Then**: proper AST-level parsing is used (not regex heuristics)

**Traceability**: FR-007, US-004-scenario-6

---

### TS-020: BDD framework auto-installed for known tech stack

**Source**: spec.md:User Story 5:scenario-1
**Type**: acceptance | **Priority**: P2

**Given**: a project with a known tech stack in plan.md
**When**: testify detects TDD is needed
**Then**: the appropriate BDD framework is installed

**Traceability**: FR-008, FR-009, SC-005, US-005-scenario-1

---

### TS-021: Scaffolded project follows conventional layout

**Source**: spec.md:User Story 5:scenario-2
**Type**: acceptance | **Priority**: P2

**Given**: a scaffolded BDD project
**When**: the directory structure is inspected
**Then**: it follows the framework's conventional layout

**Traceability**: FR-009, US-005-scenario-2

---

### TS-022: Graceful degradation when no BDD framework available

**Source**: spec.md:User Story 5:scenario-3
**Type**: acceptance | **Priority**: P2

**Given**: a tech stack with no known BDD framework
**When**: testify runs
**Then**: a visible warning is displayed explaining the verification chain is weakened, and testify falls back to generating .feature files without framework scaffolding

**Traceability**: FR-012, US-005-scenario-3

---

### TS-023: Implement verifies hash integrity before proceeding

**Source**: spec.md:User Story 6:scenario-1
**Type**: acceptance | **Priority**: P2

**Given**: a feature with .feature files and TDD enabled
**When**: implement starts
**Then**: it verifies .feature file hash integrity before proceeding

**Traceability**: FR-010, US-006-scenario-1

---

### TS-024: Step coverage verified after step definitions written

**Source**: spec.md:User Story 6:scenario-2
**Type**: acceptance | **Priority**: P2

**Given**: implementation in progress
**When**: step definitions are written
**Then**: step coverage verification is run and must pass before continuing

**Traceability**: FR-010, US-006-scenario-2

---

### TS-025: Tests expected to fail before implementation (RED)

**Source**: spec.md:User Story 6:scenario-3
**Type**: acceptance | **Priority**: P2

**Given**: step definitions written
**When**: .feature tests are run
**Then**: they are expected to fail (RED phase)

**Traceability**: FR-010, US-006-scenario-3

---

### TS-026: Tests expected to pass after implementation (GREEN)

**Source**: spec.md:User Story 6:scenario-4
**Type**: acceptance | **Priority**: P2

**Given**: production code written
**When**: .feature tests are run
**Then**: they are expected to pass (GREEN phase)

**Traceability**: FR-010, US-006-scenario-4

---

### TS-027: Quality analysis gates task completion

**Source**: spec.md:User Story 6:scenario-5
**Type**: acceptance | **Priority**: P2

**Given**: all tests passing
**When**: step quality analysis is run
**Then**: it must pass before the task is marked complete

**Traceability**: FR-010, SC-007, US-006-scenario-5

---

### TS-028: Feature file modification blocked during implementation

**Source**: spec.md:User Story 6:scenario-6
**Type**: acceptance | **Priority**: P2

**Given**: implementation in progress
**When**: the agent attempts to modify .feature files
**Then**: it is blocked — only step definitions and production code may be modified

**Traceability**: FR-011, US-006-scenario-6

---

### TS-029: Feature file tags trace to spec requirements

**Source**: spec.md:User Story 7:scenario-1
**Type**: acceptance | **Priority**: P2

**Given**: .feature files with @FR-XXX tags
**When**: analyze runs
**Then**: every tag traces to a matching requirement in spec.md

**Traceability**: FR-015, SC-001, US-007-scenario-1

---

### TS-030: Untested requirements flagged by analyze

**Source**: spec.md:User Story 7:scenario-2
**Type**: acceptance | **Priority**: P2

**Given**: a functional requirement in spec.md with no corresponding @FR-XXX tag in any .feature file
**When**: analyze runs
**Then**: it is flagged as an untested requirement

**Traceability**: FR-015, US-007-scenario-2

---

### TS-031: Step definition existence verified via dry-run

**Source**: spec.md:User Story 7:scenario-3
**Type**: acceptance | **Priority**: P2

**Given**: a @TS-XXX scenario tag
**When**: analyze runs
**Then**: it verifies a matching step definition exists (via dry-run check)

**Traceability**: FR-015, US-007-scenario-3

---

## From plan.md (Contract Tests)

### TS-032: verify-steps.sh returns PASS when all steps defined

**Source**: plan.md:D4:verify-steps
**Type**: contract | **Priority**: P1

**Given**: a project where all .feature steps have matching step definitions
**When**: verify-steps.sh --json is invoked with the features directory and plan file
**Then**: JSON output contains status "PASS", total_steps > 0, undefined_steps = 0, and empty details array

**Traceability**: FR-006, Contract:verify-steps:success

---

### TS-033: verify-steps.sh returns BLOCKED with undefined step details

**Source**: plan.md:D4:verify-steps
**Type**: contract | **Priority**: P1

**Given**: a project where some .feature steps have no step definitions
**When**: verify-steps.sh --json is invoked
**Then**: JSON output contains status "BLOCKED", undefined_steps > 0, and details array with step text, file, and line for each undefined step

**Traceability**: FR-006, Contract:verify-steps:failure

---

### TS-034: verify-steps.sh returns DEGRADED when no framework

**Source**: plan.md:D4:verify-steps
**Type**: contract | **Priority**: P2

**Given**: a project whose tech stack has no known BDD framework
**When**: verify-steps.sh --json is invoked
**Then**: JSON output contains status "DEGRADED", framework null, and a warning message

**Traceability**: FR-012, Contract:verify-steps:degraded

---

### TS-035: verify-step-quality.sh returns PASS for meaningful assertions

**Source**: plan.md:D5:verify-step-quality
**Type**: contract | **Priority**: P1

**Given**: step definitions with meaningful assertions in all Then steps
**When**: verify-step-quality.sh --json is invoked with step definitions directory and language
**Then**: JSON output contains status "PASS", quality_fail = 0, and empty details array

**Traceability**: FR-007, Contract:verify-step-quality:success

---

### TS-036: verify-step-quality.sh returns BLOCKED with quality issues

**Source**: plan.md:D5:verify-step-quality
**Type**: contract | **Priority**: P1

**Given**: step definitions with empty Then bodies or tautological assertions
**When**: verify-step-quality.sh --json is invoked
**Then**: JSON output contains status "BLOCKED", quality_fail > 0, and details array with step, file, line, issue, and severity

**Traceability**: FR-007, Contract:verify-step-quality:failure

---

### TS-037: setup-bdd.sh scaffolds framework for known tech stack

**Source**: plan.md:D6:setup-bdd
**Type**: contract | **Priority**: P2

**Given**: a project with a known tech stack and no existing BDD setup
**When**: setup-bdd.sh --json is invoked
**Then**: JSON output contains status "SCAFFOLDED", framework name, directories_created includes tests/features and tests/step_definitions

**Traceability**: FR-009, Contract:setup-bdd:success

---

### TS-038: setup-bdd.sh is idempotent

**Source**: plan.md:D6:setup-bdd
**Type**: contract | **Priority**: P2

**Given**: a project already scaffolded with a BDD framework
**When**: setup-bdd.sh --json is invoked again
**Then**: JSON output contains status "ALREADY_SCAFFOLDED" with empty directories_created and packages_installed

**Traceability**: FR-009, Contract:setup-bdd:idempotent

---

### TS-039: testify-tdd.sh extracts assertions from .feature files

**Source**: plan.md:D1:testify-tdd
**Type**: contract | **Priority**: P1

**Given**: a directory containing .feature files with Given/When/Then/And/But steps
**When**: testify-tdd.sh extract-assertions is invoked with the directory path
**Then**: all step lines are extracted, sorted by filename, with leading whitespace stripped

**Traceability**: FR-004, FR-017, Contract:testify-tdd:extract

---

### TS-040: testify-tdd.sh computes deterministic hash

**Source**: plan.md:D1:testify-tdd
**Type**: contract | **Priority**: P1

**Given**: multiple .feature files in a directory
**When**: testify-tdd.sh compute-hash is invoked twice on the same directory
**Then**: both invocations return the identical 64-character SHA-256 hex string

**Traceability**: FR-004, Contract:testify-tdd:hash-determinism

---

## From data-model.md (Validation Tests)

### TS-041: Feature file entity requires valid Gherkin syntax

**Source**: data-model.md:Feature File
**Type**: validation | **Priority**: P1

**Given**: a .feature file with invalid Gherkin syntax (e.g., Scenario Outline with no Examples)
**When**: the file is parsed by verification scripts
**Then**: a parse error is reported with file name and line number

**Traceability**: FR-001, Entity:FeatureFile

---

### TS-042: Assertion hash entity includes all required fields

**Source**: data-model.md:Assertion Hash
**Type**: validation | **Priority**: P1

**Given**: testify-tdd.sh store-hash is invoked on a features directory
**When**: context.json is read
**Then**: the testify object contains assertion_hash (64-char hex), generated_at (ISO 8601), features_dir (relative path), and file_count (integer > 0)

**Traceability**: FR-004, Entity:AssertionHash

---

### TS-043: Feature file state transition: generated to hashed

**Source**: data-model.md:State Transitions
**Type**: validation | **Priority**: P1

**Given**: .feature files generated by testify
**When**: testify-tdd.sh store-hash is invoked
**Then**: the hash is stored in context.json and the files transition to "hashed" state

**Traceability**: FR-004, Entity:FeatureFile:state

---

### TS-044: Step definition state transition: undefined to verified

**Source**: data-model.md:State Transitions
**Type**: validation | **Priority**: P2

**Given**: step definitions written for all .feature steps
**When**: verify-steps.sh and verify-step-quality.sh both return PASS
**Then**: step definitions transition to "verified" state

**Traceability**: FR-006, FR-007, Entity:StepDefinition:state

---

## From spec.md (Gap Coverage)

### TS-045: Testify does not generate test-specs.md

**Source**: spec.md:Requirements:FR-003
**Type**: acceptance | **Priority**: P1

**Given**: a feature with a completed spec.md
**When**: testify runs and generates .feature files
**Then**: no test-specs.md file is created or updated in the tests/ directory

**Traceability**: FR-003, SC-001

---

### TS-046: All new scripts have both bash and PowerShell implementations

**Source**: spec.md:Requirements:FR-013
**Type**: acceptance | **Priority**: P1

**Given**: a new verification or scaffolding script (verify-steps, verify-step-quality, setup-bdd)
**When**: the script is delivered
**Then**: both .sh and .ps1 implementations exist and produce identical JSON output for the same inputs

**Traceability**: FR-013, SC-006

---

### TS-047: All new scripts have automated tests

**Source**: spec.md:Requirements:FR-014
**Type**: acceptance | **Priority**: P1

**Given**: a new script (verify-steps, verify-step-quality, setup-bdd)
**When**: the test suite is inspected
**Then**: BATS tests exist for the bash implementation and Pester tests exist for the PowerShell implementation

**Traceability**: FR-014

---

## Summary

| Source | Count | Types |
|--------|-------|-------|
| spec.md | 34 | acceptance |
| plan.md | 9 | contract |
| data-model.md | 4 | validation |
| **Total** | **47** | |
