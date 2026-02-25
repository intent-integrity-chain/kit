# Feature Specification: BDD Verification Chain

**Feature Branch**: `30-bdd-verification-chain`
**Created**: 2026-02-21
**Status**: Draft
**Input**: User description: "Replace test-specs.md with Gherkin .feature files and add BDD verification chain (GitHub Issue #30)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate Gherkin Feature Files from Specifications (Priority: P1)

As a developer using IIKit with TDD enabled, I want testify to generate standard Gherkin `.feature` files instead of `test-specs.md` so that my test specifications are directly executable by BDD frameworks — closing the gap where the spec was separate from the test.

**Why this priority**: This is the foundational change. Nothing else works without `.feature` file generation. It replaces the core output artifact of testify.

**Independent Test**: Can be tested by running testify on any feature with a spec.md and verifying that `.feature` files are produced in the correct directory with valid Gherkin syntax.

**Acceptance Scenarios**:

1. **Given** a feature with a completed spec.md, **When** testify runs, **Then** one or more `.feature` files are generated in `tests/features/`
2. **Given** a spec with multiple user stories and requirements, **When** testify runs, **Then** every functional requirement (FR-XXX) and user story (US-XXX) is traceable via Gherkin tags in the generated files
3. **Given** a spec with parameterized acceptance scenarios, **When** testify runs, **Then** `Scenario Outline:` with `Examples:` tables are used where scenarios differ only by data
4. **Given** a spec where 3+ scenarios share setup preconditions, **When** testify runs, **Then** `Background:` is used to avoid duplication
5. **Given** a spec with distinct business rule groupings, **When** testify runs, **Then** `Rule:` blocks group related scenarios

---

### User Story 2 - Feature File Integrity Verification (Priority: P1)

As a developer, I want `.feature` file assertions hashed and verified so that agents cannot silently modify test specifications during implementation.

**Why this priority**: Without integrity verification, the BDD chain has no teeth — an agent could rewrite `.feature` files to match buggy code.

**Independent Test**: Can be tested by hashing `.feature` files after testify, modifying a step line, and verifying that the pre-commit hook blocks the commit.

**Acceptance Scenarios**:

1. **Given** generated `.feature` files, **When** testify completes, **Then** a combined SHA-256 hash of all assertion lines is stored
2. **Given** a stored hash, **When** a `.feature` file step line is modified, **Then** the pre-commit hook detects the mismatch and blocks the commit
3. **Given** a stored hash, **When** only whitespace or comments change in `.feature` files, **Then** the hash still validates (whitespace-normalized)
4. **Given** multiple `.feature` files, **When** the hash is computed, **Then** files are processed in sorted filename order for deterministic results

---

### User Story 3 - Step Coverage Verification (Priority: P1)

As a developer, I want to verify that every step in my `.feature` files has a matching step definition so that no scenario goes unimplemented.

**Why this priority**: This is the core of the verification chain — the mechanism that prevents `assert True` for every scenario. Without it, the agent can write empty step definitions.

**Independent Test**: Can be tested by generating `.feature` files, writing partial step definitions (some missing), and verifying that the verification reports the undefined steps.

**Acceptance Scenarios**:

1. **Given** `.feature` files and a project with step definitions, **When** step coverage is verified, **Then** all steps with matching definitions are reported as matched
2. **Given** `.feature` files with steps that have no step definitions, **When** step coverage is verified, **Then** each undefined step is reported with file and line number
3. **Given** all steps have matching definitions, **When** step coverage is verified, **Then** the verification passes with a count of total and matched steps
4. **Given** any undefined steps exist, **When** step coverage is verified, **Then** the verification fails with exit code non-zero

---

### User Story 4 - Step Quality Analysis (Priority: P1)

As a developer, I want step definition quality analyzed so that trivial implementations (empty bodies, tautological assertions) are caught.

**Why this priority**: Step coverage alone is insufficient — an agent can define every step with `pass` or `assert True`. Quality analysis catches this.

**Independent Test**: Can be tested by writing step definitions with empty Then bodies, tautological assertions, and proper assertions — verifying that only proper ones pass.

**Acceptance Scenarios**:

1. **Given** a Then step definition with an empty body, **When** quality is analyzed, **Then** it is flagged as FAIL with issue "EMPTY_BODY"
2. **Given** a Then step definition containing only `assert True` or equivalent tautology, **When** quality is analyzed, **Then** it is flagged as FAIL with issue "TAUTOLOGY"
3. **Given** a Then step definition with no assertion keywords, **When** quality is analyzed, **Then** it is flagged as FAIL with issue "NO_ASSERTION"
4. **Given** a When step definition with an empty body, **When** quality is analyzed, **Then** it is flagged as FAIL with issue "EMPTY_BODY"
5. **Given** a Then step definition with meaningful assertions, **When** quality is analyzed, **Then** it passes quality analysis
6. **Given** step definitions in any supported language, **When** quality is analyzed, **Then** proper AST-level parsing is used (not regex heuristics)

---

### User Story 5 - BDD Framework Scaffolding (Priority: P2)

As a developer, I want the BDD framework automatically detected and scaffolded when testify runs so that the project is ready for step definition writing without manual setup.

**Why this priority**: Reduces friction between testify and implement. Without scaffolding, the developer must manually install and configure the BDD framework.

**Independent Test**: Can be tested by running testify on a project with a known tech stack and verifying that the correct BDD framework is installed and directory structure is created.

**Acceptance Scenarios**:

1. **Given** a project with a known tech stack in plan.md, **When** testify detects TDD is needed, **Then** the appropriate BDD framework is installed
2. **Given** a scaffolded BDD project, **When** the directory structure is inspected, **Then** it follows the framework's conventional layout
3. **Given** a tech stack with no known BDD framework, **When** testify runs, **Then** a visible warning is displayed explaining the verification chain is weakened, and testify falls back to generating `.feature` files without framework scaffolding

---

### User Story 6 - Implement Skill Enforces BDD Chain (Priority: P2)

As a developer, I want the implement skill to enforce the full BDD verification chain during implementation so that the red-green-refactor cycle is actually followed.

**Why this priority**: The verification scripts are useless if the implement skill doesn't invoke them at the right points in the workflow.

**Independent Test**: Can be tested by running implement on a feature with `.feature` files and verifying that step definitions are written first, dry-run passes, tests go red, code is written, tests go green, and quality analysis passes.

**Acceptance Scenarios**:

1. **Given** a feature with `.feature` files and TDD enabled, **When** implement starts, **Then** it verifies `.feature` file hash integrity before proceeding
2. **Given** implementation in progress, **When** step definitions are written, **Then** step coverage verification is run and must pass before continuing
3. **Given** step definitions written, **When** `.feature` tests are run, **Then** they are expected to fail (RED phase)
4. **Given** production code written, **When** `.feature` tests are run, **Then** they are expected to pass (GREEN phase)
5. **Given** all tests passing, **When** step quality analysis is run, **Then** it must pass before the task is marked complete
6. **Given** implementation in progress, **When** the agent attempts to modify `.feature` files, **Then** it is blocked — only step definitions and production code may be modified

---

### User Story 7 - Cross-Artifact Traceability (Priority: P2)

As a developer, I want the analyze skill to verify that `.feature` file tags trace back to spec.md requirements so that no requirement is left untested and no test is orphaned.

**Why this priority**: Traceability is the bridge between specification and test. Without it, the chain has gaps.

**Independent Test**: Can be tested by creating `.feature` files with tags referencing FR-XXX and US-XXX, then running analyze and verifying all references resolve.

**Acceptance Scenarios**:

1. **Given** `.feature` files with `@FR-XXX` tags, **When** analyze runs, **Then** every tag traces to a matching requirement in spec.md
2. **Given** a functional requirement in spec.md with no corresponding `@FR-XXX` tag in any `.feature` file, **When** analyze runs, **Then** it is flagged as an untested requirement
3. **Given** a `@TS-XXX` scenario tag, **When** analyze runs, **Then** it verifies a matching step definition exists (via dry-run check)

---

### Edge Cases

- What happens when `.feature` files contain syntax errors? Verification scripts must report parse errors with file and line number.
- How does the system handle `.feature` files that reference FR-XXX IDs not present in spec.md? Analyze must flag orphaned traceability tags.
- What happens when the tech stack changes between plan iterations? BDD framework scaffolding must handle re-detection gracefully.
- What if testify is re-run after `.feature` files already exist? The hash must be recomputed and the old hash replaced.
- What happens when no `.feature` files exist but testify phase is checked? Pipeline reports testify as not started.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Testify skill MUST generate standard Gherkin `.feature` files in `tests/features/` directory
- **FR-002**: Generated `.feature` files MUST use Gherkin tags for all traceability metadata: `@TS-XXX` (test spec ID), `@FR-XXX` (functional requirement), `@US-XXX` (user story), `@P1`/`@P2`/`@P3` (priority), `@acceptance`/`@contract`/`@validation` (type)
- **FR-003**: Testify MUST NOT generate `test-specs.md` — `.feature` files are the sole test specification artifact
- **FR-004**: A combined SHA-256 hash of all assertion lines across all `.feature` files (sorted by filename) MUST be computed and stored after generation
- **FR-005**: Pre-commit and post-commit hooks MUST detect and block commits with tampered `.feature` file assertions
- **FR-006**: A step coverage verification mechanism MUST detect undefined and pending steps by performing a framework dry-run in strict mode
- **FR-007**: A step quality analysis mechanism MUST detect empty, trivial, and tautological step definition bodies using AST-level parsing
- **FR-008**: BDD framework MUST be auto-detected from the tech stack defined in plan.md
- **FR-009**: BDD framework installation and directory scaffolding MUST be automated when testify detects TDD is needed
- **FR-010**: The implement skill MUST enforce the BDD verification chain: hash check, step coverage, red-green cycle, step quality
- **FR-011**: `.feature` files MUST NOT be modified during implementation — only step definitions and production code
- **FR-012**: When no BDD framework is available for the tech stack, the system MUST fall back to `.feature` file generation with freeform tests and display a visible warning that the verification chain is not integral
- **FR-013**: All verification and scaffolding scripts MUST have both bash and PowerShell implementations with identical behavior
- **FR-014**: All new scripts MUST have automated tests
- **FR-015**: The analyze skill MUST verify that all `@FR-XXX` tags in `.feature` files trace back to spec.md and flag untested requirements
- **FR-016**: Testify MUST use Gherkin advanced constructs where appropriate: `Background:` for shared preconditions (3+ scenarios), `Scenario Outline:` with `Examples:` for parameterized tests, `Rule:` for business rule grouping
- **FR-017**: `.feature` file hash extraction MUST normalize whitespace before hashing to prevent cosmetic changes from invalidating the hash

### Key Entities

- **Feature File**: A standard Gherkin `.feature` file containing scenarios with traceability tags. Lives in `tests/features/`. Multiple files per feature directory.
- **Step Definition**: Glue code binding Gherkin steps to application calls. Written by implement skill. Lives in `tests/step_definitions/`.
- **Assertion Hash**: Combined SHA-256 hash of all Given/When/Then/And/But lines across all `.feature` files in a feature directory. Stored in `context.json`.
- **BDD Framework**: The language-specific test runner that executes `.feature` files via step definitions. Auto-detected from plan.md tech stack.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every functional requirement in spec.md has a corresponding `@FR-XXX` tag in at least one `.feature` file scenario (100% traceability coverage)
- **SC-002**: Step coverage verification catches 100% of undefined steps (no false negatives) — verified by dry-run in strict mode
- **SC-003**: Step quality analysis catches empty bodies, `pass`/`return`-only bodies, and tautological assertions (`assert True`, `expect(true).toBe(true)`) with zero false negatives
- **SC-004**: Pre-commit hook blocks 100% of commits containing modified `.feature` assertion lines without a corresponding hash update
- **SC-005**: BDD framework auto-detection covers all tech stacks listed in the framework lookup table
- **SC-006**: All scripts produce identical output on both bash and PowerShell for the same inputs
- **SC-007**: The implement skill never marks a TDD task as complete without passing step coverage and step quality checks
