# Tasks: BDD Verification Chain

**Input**: Design documents from `/specs/031-bdd-verification-chain/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/, test-specs.md

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[USn]**: Which user story this task belongs to
- Test spec references: TS-XXX from tests/test-specs.md

## Phase 1: Foundational (testify-tdd.sh — blocks all stories)

**Purpose**: Modify the core hash infrastructure to support .feature files instead of test-specs.md. All downstream work depends on this.

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T001 Modify extract_assertions() in .claude/skills/iikit-core/scripts/bash/testify-tdd.sh to extract Given/When/Then/And/But lines from .feature files instead of **Given**:/**When**:/**Then**: from test-specs.md. Accept both directory path (tests/features/) and single file path. Sort files by name, strip leading whitespace, collapse internal whitespace. [TS-039]
- [x] T002 Modify compute_assertion_hash() in .claude/skills/iikit-core/scripts/bash/testify-tdd.sh to handle directory input (glob *.feature, sort, concatenate extracted lines, SHA-256). Return NO_ASSERTIONS if no step lines found. [TS-040]
- [x] T003 Modify store_assertion_hash() in .claude/skills/iikit-core/scripts/bash/testify-tdd.sh to store features_dir and file_count in context.json testify object (replacing test_specs_file). [TS-042, TS-043]
- [x] T004 Modify derive_context_path() in .claude/skills/iikit-core/scripts/bash/testify-tdd.sh to support features directory path derivation (tests/features/ → context.json two levels up). [TS-042]
- [x] T005 Modify comprehensive_integrity_check() in .claude/skills/iikit-core/scripts/bash/testify-tdd.sh to work with .feature directory input instead of single test-specs.md file. [TS-006]
- [x] T006 Update BATS tests in tests/bash/testify-tdd.bats for all modified functions — add .feature file fixtures, directory-based hash tests, whitespace normalization tests. [TS-006, TS-008, TS-009]
- [x] T007 [P] Modify extract_assertions() in .claude/skills/iikit-core/scripts/powershell/testify-tdd.ps1 — identical behavior to bash T001. [TS-039, TS-046]
- [x] T008 [P] Modify compute_assertion_hash() in .claude/skills/iikit-core/scripts/powershell/testify-tdd.ps1 — identical behavior to bash T002. [TS-040, TS-046]
- [x] T009 [P] Modify store_assertion_hash() in .claude/skills/iikit-core/scripts/powershell/testify-tdd.ps1 — identical behavior to bash T003. [TS-042, TS-043, TS-046]
- [x] T010 [P] Modify derive_context_path() and comprehensive check in .claude/skills/iikit-core/scripts/powershell/testify-tdd.ps1 — identical behavior to bash T004/T005. [TS-006, TS-042, TS-046]

**Checkpoint**: testify-tdd.sh/ps1 can hash .feature files. All downstream work unblocked.

---

## Phase 2: US-1 — Generate Gherkin Feature Files (Priority: P1)

**Goal**: Testify skill generates .feature files instead of test-specs.md.

**Independent Test**: Run testify on a feature with spec.md and verify .feature files in tests/features/ with valid Gherkin and traceability tags.

- [x] T011 [US1] Rewrite the test specification generation section of .claude/skills/iikit-05-testify/SKILL.md to instruct the agent to generate standard Gherkin .feature files in FEATURE_DIR/tests/features/ instead of tests/test-specs.md. Include Gherkin tag conventions (@TS-XXX, @FR-XXX, @US-XXX, @P1-3, @acceptance/@contract/@validation). [TS-001, TS-002]
- [x] T012 [US1] Add Gherkin advanced construct guidance to .claude/skills/iikit-05-testify/SKILL.md: Background (3+ shared Given), Scenario Outline + Examples (data-only variance), Rule (business rule grouping). [TS-003, TS-004, TS-005]
- [x] T013 [US1] Update hash storage commands in .claude/skills/iikit-05-testify/SKILL.md to use directory path (FEATURE_DIR/tests/features) instead of file path (tests/test-specs.md). Update both bash and PowerShell command examples. [TS-006]
- [x] T014 [US1] Remove all references to test-specs.md output format from .claude/skills/iikit-05-testify/SKILL.md. Update DO NOT MODIFY markers for .feature file context. [TS-045]
- [x] T015 [US1] Add .feature file syntax error handling guidance to .claude/skills/iikit-05-testify/SKILL.md — agent must validate generated Gherkin syntax. [TS-041]

**Checkpoint**: Testify generates .feature files with traceability tags and stores hash.

---

## Phase 3: US-2 — Feature File Integrity Verification (Priority: P1)

**Goal**: Pre-commit and post-commit hooks detect and block tampered .feature files.

- [x] T016 [US2] Modify pre-commit-hook.sh in .claude/skills/iikit-core/scripts/bash/pre-commit-hook.sh to detect staged .feature files (grep for tests/features/.*\.feature$) instead of test-specs.md. Update fast path exit condition. [TS-007]
- [x] T017 [US2] Modify staged file extraction in pre-commit-hook.sh to handle multiple .feature files — extract each staged .feature to temp, compute combined hash, compare against stored hash. [TS-009]
- [x] T018 [US2] Modify context.json reading strategy in pre-commit-hook.sh for new testify object format (features_dir, file_count instead of test_specs_file). [TS-042]
- [x] T019 [US2] Modify git notes search in pre-commit-hook.sh to match .feature directory paths in note entries. [TS-007]
- [x] T020 [US2] Modify post-commit-hook.sh in .claude/skills/iikit-core/scripts/bash/post-commit-hook.sh to detect committed .feature files and store combined hash as git note. Update note entry format for directory-based paths. [TS-006]
- [x] T021 [US2] Update BATS tests in tests/bash/pre-commit-hook.bats — add .feature file staging fixtures, multi-file hash tests, whitespace change tests. [TS-007, TS-008]
- [x] T022 [P] [US2] Modify pre-commit-hook.ps1 in .claude/skills/iikit-core/scripts/powershell/pre-commit-hook.ps1 — identical behavior to bash T016-T019. [TS-007, TS-009, TS-046]
- [x] T023 [P] [US2] Modify post-commit-hook.ps1 in .claude/skills/iikit-core/scripts/powershell/post-commit-hook.ps1 — identical behavior to bash T020. [TS-006, TS-046]

**Checkpoint**: Commits with tampered .feature files are blocked. Integrity chain intact.

---

## Phase 4: US-3 — Step Coverage Verification (Priority: P1)

**Goal**: New script detects undefined/pending steps via BDD framework dry-run.

- [x] T024 [US3] Create verify-steps.sh in .claude/skills/iikit-core/scripts/bash/verify-steps.sh with framework detection (parse plan.md for tech stack keywords, fallback to file extension heuristics). Implement lookup table per plan D4. [TS-010, TS-011, TS-012, TS-013]
- [x] T025 [US3] Implement dry-run execution in verify-steps.sh — invoke framework-specific dry-run command, parse output for undefined/pending steps, produce JSON output per contracts/script-outputs.md. [TS-032, TS-033]
- [x] T026 [US3] Implement DEGRADED mode in verify-steps.sh — when no framework detected, return status DEGRADED with warning message. [TS-034]
- [x] T027 [US3] Create BATS tests in tests/bash/verify-steps.bats — test framework detection, PASS/BLOCKED/DEGRADED responses, JSON output schema validation. [TS-032, TS-033, TS-034, TS-047]
- [x] T028 [P] [US3] Create verify-steps.ps1 in .claude/skills/iikit-core/scripts/powershell/verify-steps.ps1 — identical behavior to bash T024-T026. [TS-010, TS-011, TS-012, TS-013, TS-046]

**Checkpoint**: Step coverage verification script works for all listed frameworks.

---

## Phase 5: US-4 — Step Quality Analysis (Priority: P1)

**Goal**: New script detects empty, trivial, and tautological step definition bodies using AST parsing.

- [x] T029 [US4] Create verify-step-quality.sh in .claude/skills/iikit-core/scripts/bash/verify-step-quality.sh with language detection and AST parser selection per plan D5. [TS-014, TS-015, TS-016, TS-017, TS-018]
- [x] T030 [US4] Implement Python AST analysis in verify-step-quality.sh — use python3 -c with ast module to parse step files, extract Then/When/Given function bodies, check for empty bodies, tautologies, and missing assertions. [TS-019]
- [x] T031 [US4] Implement JavaScript/TypeScript analysis in verify-step-quality.sh — use node -e for basic AST parsing of step files, same quality checks as Python. [TS-019]
- [x] T032 [US4] Implement Go analysis in verify-step-quality.sh — use go/ast via embedded Go script for step file parsing. [TS-019]
- [x] T033 [US4] Implement regex fallback in verify-step-quality.sh for unsupported languages (Java, Rust, C#) — flag as DEGRADED_ANALYSIS in output. [TS-035, TS-036]
- [x] T034 [US4] Create BATS tests in tests/bash/verify-step-quality.bats — test each language parser, PASS/BLOCKED responses, DEGRADED_ANALYSIS mode, JSON output validation. [TS-014, TS-015, TS-016, TS-035, TS-036, TS-047]
- [x] T035 [P] [US4] Create verify-step-quality.ps1 in .claude/skills/iikit-core/scripts/powershell/verify-step-quality.ps1 — identical behavior to bash T029-T033. [TS-014, TS-015, TS-016, TS-017, TS-018, TS-046]

**Checkpoint**: Step quality analysis catches empty/trivial/tautological implementations.

---

## Phase 6: US-5 — BDD Framework Scaffolding (Priority: P2)

**Goal**: Auto-detect and scaffold BDD framework from tech stack.

- [x] T036 [US5] Create setup-bdd.sh in .claude/skills/iikit-core/scripts/bash/setup-bdd.sh with framework detection from plan.md, directory creation (tests/features/, tests/step_definitions/), and framework installation per plan D6. [TS-020, TS-021]
- [x] T037 [US5] Implement idempotency in setup-bdd.sh — detect existing scaffolding, return ALREADY_SCAFFOLDED. [TS-038]
- [x] T038 [US5] Implement NO_FRAMEWORK fallback in setup-bdd.sh — create directory structure without installing framework, return warning. [TS-022, TS-037]
- [x] T039 [US5] Create BATS tests in tests/bash/setup-bdd.bats — test framework detection, scaffolding, idempotency, NO_FRAMEWORK mode. [TS-020, TS-021, TS-037, TS-038, TS-047]
- [x] T040 [P] [US5] Create setup-bdd.ps1 in .claude/skills/iikit-core/scripts/powershell/setup-bdd.ps1 — identical behavior to bash T036-T038. [TS-020, TS-021, TS-046]

**Checkpoint**: BDD framework auto-detected and scaffolded for all listed tech stacks.

---

## Phase 7: US-6 — Implement Skill Enforces BDD Chain (Priority: P2)

**Goal**: Implement skill verifies hash, coverage, quality, and enforces red-green cycle.

**Depends on**: Phase 1 (testify-tdd.sh), Phase 4 (verify-steps.sh), Phase 5 (verify-step-quality.sh)

- [x] T041 [US6] Update TDD Support Check section in .claude/skills/iikit-08-implement/SKILL.md to call testify-tdd.sh comprehensive-check with .feature directory path instead of test-specs.md file path. Update both bash and PowerShell command examples. [TS-023]
- [x] T042 [US6] Update Test Execution Enforcement section in .claude/skills/iikit-08-implement/SKILL.md to add BDD verification chain: write step definitions → verify-steps.sh (must PASS) → run tests (expect RED) → write production code → run tests (expect GREEN) → verify-step-quality.sh (must PASS). [TS-024, TS-025, TS-026, TS-027]
- [x] T043 [US6] Add .feature file immutability rule to .claude/skills/iikit-08-implement/SKILL.md — agent MUST NOT modify .feature files during implementation, only step definitions and production code. [TS-028]
- [x] T044 [US6] Add task completion gate to .claude/skills/iikit-08-implement/SKILL.md — task not marked complete until verify-steps.sh and verify-step-quality.sh both return PASS. [TS-044]

**Checkpoint**: Implement skill enforces the full BDD verification chain.

---

## Phase 8: US-7 — Cross-Artifact Traceability (Priority: P2)

**Goal**: Analyze skill verifies .feature tag traceability to spec.md.

- [x] T045 [US7] Add .feature file tag extraction to coverage detection in .claude/skills/iikit-07-analyze/SKILL.md — parse @FR-XXX, @US-XXX, @TS-XXX tags from all .feature files in tests/features/. [TS-029]
- [x] T046 [US7] Add untested requirement detection to .claude/skills/iikit-07-analyze/SKILL.md — flag FR-XXX from spec.md that have no corresponding @FR-XXX tag in any .feature file. [TS-030]
- [x] T047 [US7] Add orphaned tag detection to .claude/skills/iikit-07-analyze/SKILL.md — flag @FR-XXX tags in .feature files that reference IDs not present in spec.md. [TS-029]
- [x] T048 [US7] Add optional step definition existence check to .claude/skills/iikit-07-analyze/SKILL.md — run verify-steps.sh as part of analysis when .feature files and step definitions exist. [TS-031]

**Checkpoint**: Analyze validates full traceability from spec → .feature → step definitions.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation, and cleanup.

- [x] T049 [P] Remove all references to test-specs.md format from .claude/skills/iikit-05-testify/SKILL.md, .claude/skills/iikit-08-implement/SKILL.md, and .claude/skills/iikit-07-analyze/SKILL.md (ensure no residual old-format references). [TS-045]
- [x] T050 [P] Update testspec-template.md in .claude/skills/iikit-core/templates/testspec-template.md — either remove (replaced by .feature files) or update to reflect new format. [TS-045]
- [x] T051 [P] Modify verify-test-execution.sh in .claude/skills/iikit-core/scripts/bash/verify-test-execution.sh to recognize BDD framework test output (.feature execution logs) in addition to existing test runner output. Update PowerShell equivalent verify-test-execution.ps1. [TS-025, TS-026]
- [x] T052 [P] Create Pester tests for verify-steps.ps1, verify-step-quality.ps1, and setup-bdd.ps1 — equivalent coverage to BATS tests T027, T034, T039. [TS-046, TS-047, Constitution III]
- [x] T053 Run quickstart.md validation scenarios end-to-end to verify all scripts work together. [TS-006, TS-007, TS-032, TS-035]

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Foundational)
  ├──→ Phase 2 (US-1: Testify SKILL.md)
  ├──→ Phase 3 (US-2: Hooks)
  └──→ Phase 7 (US-6: Implement SKILL.md) ──→ also needs Phase 4 + Phase 5
Phase 4 (US-3: verify-steps) ─── starts immediately, no dependencies
Phase 5 (US-4: verify-step-quality) ─── starts immediately, no dependencies
Phase 6 (US-5: setup-bdd) ─── starts immediately, no dependencies
Phase 8 (US-7: Analyze SKILL.md) ─── starts immediately, no dependencies
Phase 9 (Polish) ─── after all other phases
```

### Parallel Opportunities

After Phase 1 completes, the following can run in parallel:
- **Batch A**: Phase 2 (US-1) + Phase 3 (US-2) — both depend on Phase 1 only
- **Batch B**: Phase 4 (US-3) + Phase 5 (US-4) + Phase 6 (US-5) + Phase 8 (US-7) — no dependencies on Phase 1

Within phases, tasks marked [P] can run in parallel (different files, no dependencies). PowerShell implementations [P] can run parallel with their BATS test counterparts.

### Critical Path

Phase 1 → Phase 7 (US-6) is the critical path: testify-tdd.sh modifications must complete before implement SKILL.md can reference verify-steps.sh and verify-step-quality.sh outputs.

**Total tasks**: 53
**Parallel batches**: 6 (within phases) + 2 (cross-phase)
**MVP scope**: Phase 1 + Phase 2 + Phase 3 = core .feature generation + hash integrity (24 tasks)

---

## Notes

- [P] tasks = different files, no dependencies
- [USn] label maps task to specific user story
- Each phase can be independently verified at its checkpoint
- PowerShell tasks [P] alongside their bash counterparts within each phase
- TS-XXX references link to tests/test-specs.md acceptance criteria
