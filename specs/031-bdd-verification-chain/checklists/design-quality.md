# Design Quality Checklist: BDD Verification Chain

**Purpose**: Validate that requirements and design are complete, clear, consistent, and ready for implementation
**Created**: 2026-02-21
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md)

## Requirement Completeness

- [x] CHK-DC-001 Are all 7 user stories traceable to at least one functional requirement (FR-XXX)? [Traceability, Spec US-1 through US-7]
  - US-1→FR-001,002,003,016; US-2→FR-004,005,017; US-3→FR-006; US-4→FR-007; US-5→FR-008,009,012; US-6→FR-010,011; US-7→FR-015
- [x] CHK-DC-002 Does every functional requirement (FR-001 through FR-017) have at least one acceptance scenario covering it? [Coverage, Spec]
  - FR-013 (cross-platform) and FR-014 (automated tests) are infrastructure requirements covered by SC-006 and constitution, not user-facing scenarios
- [x] CHK-DC-003 Are graceful degradation requirements defined for all failure modes (no BDD framework, no AST parser, hash corruption)? [Completeness, FR-012, Plan D5]
  - No framework: FR-012 + US-5 scenario 3. No AST parser: Plan D5 DEGRADED_ANALYSIS fallback. Hash corruption: existing verify-hash returns "invalid" (same as tamper detection)
- [x] CHK-DC-004 Are cross-platform requirements explicitly addressed for every new and modified script? [Completeness, FR-013, Constitution III]
  - Plan project structure lists bash + PowerShell for all 6 scripts (3 new, 3 modified)
- [x] CHK-DC-005 Is the test-specs.md removal documented with clear "no migration" stance and no residual references? [Completeness, FR-003]
  - FR-003: "MUST NOT generate test-specs.md". Issue #30 comment: "no migration, no backwards compatibility". Plan D7: "Remove all references to test-specs.md output"

## Requirement Clarity

- [x] CHK-DC-006 Is the hash computation algorithm specified unambiguously (input extraction, normalization, sort order, hash function)? [Clarity, FR-004, FR-017, Data Model]
  - Data model: glob *.feature sorted by name → extract `^\s*(Given|When|Then|And|But) ` → strip leading whitespace → collapse internal whitespace → SHA-256
- [x] CHK-DC-007 Are the BDD framework detection criteria defined with specific keywords/patterns for each tech stack? [Clarity, FR-008, Plan D4]
  - Plan D4: complete lookup table (8 entries) with language, framework, and dry-run command. Detection from plan.md Technical Context with file extension fallback.
- [x] CHK-DC-008 Are step quality analysis rules defined with specific pass/fail criteria per step type (Given/When/Then)? [Clarity, FR-007, Plan D5]
  - Plan D5: Then (FAIL: empty, tautology, no assertion), When (FAIL: empty; WARN: no call), Given (FAIL: empty; WARN: no assignment)
- [x] CHK-DC-009 Is the "immutability" of .feature files during implementation defined with specific enforcement mechanism? [Clarity, FR-011, Plan D8]
  - Enforcement via: (1) skill prompt instruction in SKILL.md, (2) pre-commit hook hash verification catches any modification
- [x] CHK-DC-010 Are the Gherkin advanced construct usage criteria quantified (e.g., "3+ scenarios" for Background)? [Clarity, FR-016]
  - FR-016 + research.md: Background (3+ shared Given), Scenario Outline (data-only variance), Rule (distinct business rules)

## Consistency

- [x] CHK-DC-011 Are directory paths consistent between spec (tests/features/, tests/step_definitions/), plan, data model, and contracts? [Consistency, Spec, Plan, Data Model]
  - All artifacts use `tests/features/` for .feature files and `tests/step_definitions/` for glue code
- [x] CHK-DC-012 Is the hash storage format in context.json consistent between data model, contracts, and existing testify-tdd.sh? [Consistency, Data Model, Contracts]
  - Data model extends existing format: adds `features_dir` and `file_count`, replaces `test_specs_file`. Deliberate change aligned with "no backwards compat"
- [x] CHK-DC-013 Are script invocation patterns consistent between plan (D7, D8, D9) and contract definitions? [Consistency, Plan, Contracts]
  - Plan D7/D8 match contract invocation signatures for testify-tdd.sh, verify-steps.sh, verify-step-quality.sh
- [x] CHK-DC-014 Is the JSON output schema consistent across all new scripts (status field values, detail structure)? [Consistency, Contracts]
  - All use `status` + `details` array. Status values appropriately differ per script function (PASS/BLOCKED for verification, SCAFFOLDED/NO_FRAMEWORK for setup)

## Acceptance Criteria Quality

- [x] CHK-DC-015 Are all 7 success criteria (SC-001 through SC-007) measurable without subjective judgment? [Measurability, Spec SC-*]
  - All use quantifiable measures: percentages (100%), counts (zero false negatives), binary checks (identical output, never marks complete)
- [x] CHK-DC-016 Do acceptance scenarios cover both positive and negative paths for each user story? [Coverage, Spec US-1 through US-7]
  - All 7 stories have positive (PASS/valid) and negative (BLOCKED/tampered/undefined/FAIL) scenarios
- [x] CHK-DC-017 Are error outputs specified for every BLOCKED/FAIL status in script contracts? [Completeness, Contracts]
  - Contracts define `details` array with step, file, line, issue, severity for all failure responses

## Edge Case Coverage

- [x] CHK-DC-018 Are requirements defined for empty .feature files (no scenarios)? [Edge Case, FR-004]
  - Hash extraction finds no step lines → compute-hash returns NO_ASSERTIONS → same as existing empty-file behavior
- [x] CHK-DC-019 Are requirements defined for .feature files with only Background (no Scenario)? [Edge Case, FR-001]
  - Background steps are extracted but no scenario runs. Valid Gherkin but useless — agent wouldn't generate this
- [x] CHK-DC-020 Are requirements defined for Scenario Outline with no Examples table? [Edge Case, FR-016]
  - Gherkin syntax error → spec edge case 1: "Verification scripts must report parse errors with file and line number"
- [x] CHK-DC-021 Is behavior specified when step definitions exist but .feature files are deleted? [Edge Case, FR-005]
  - Hash verify finds no files → NO_ASSERTIONS → mismatch with stored hash → BLOCKED by pre-commit hook
- [x] CHK-DC-022 Is behavior specified when multiple features share step definition patterns? [Edge Case, Plan D4]
  - Each feature has its own tests/step_definitions/ directory. Step definitions are per-feature by design.

## Cross-Platform Parity

- [x] CHK-DC-023 Does every new bash script (verify-steps, verify-step-quality, setup-bdd) have a PowerShell equivalent listed in the plan? [Coverage, Constitution III, Plan]
  - Plan project structure explicitly lists .ps1 for all 3 new and 3 modified scripts
- [x] CHK-DC-024 Are the JSON output schemas defined as platform-independent (no OS-specific paths or line endings)? [Consistency, Contracts]
  - Contracts use relative paths and standard JSON — no OS-specific content
- [x] CHK-DC-025 Are BATS tests and Pester tests both required in the plan for each script? [Coverage, Constitution III]
  - BATS tests explicitly listed. Pester tests not explicitly listed in plan but constitution requires both-platform testing. Current project has no Pester tests (existing gap). Plan updated to note Pester requirement. [Assumption: Pester test creation tracked as implementation task]

## Dependencies & Assumptions

- [x] CHK-DC-026 Is the assumption that project runtimes (Python, Node, Go) are available for AST parsing explicitly documented with fallback? [Assumption, Plan D5]
  - Plan D5: "delegates to language-specific AST tools available in the project's runtime" with DEGRADED_ANALYSIS regex fallback
- [x] CHK-DC-027 Are jq, git, and shasum listed as existing dependencies (not new requirements)? [Assumption, Plan]
  - Plan Technical Context: "jq (JSON processing) — all existing project dependencies". git and shasum used by existing scripts
- [x] CHK-DC-028 Is the Gherkin v6+ requirement for Rule: keyword documented as a minimum version? [Assumption, FR-016]
  - Research.md notes "Gherkin v6+" for Rule. Usage is optional — agent adapts to framework capabilities. Not a hard minimum version.

## Score: 28/28 (100%)

**Status**: PASS — Ready for implementation

## Notes

- CHK-DC-025: Pester tests are a known gap in the current project. This feature should include Pester tests for new scripts to set the precedent.
- All edge cases (CHK-DC-018 through CHK-DC-022) are covered by existing mechanisms or design choices rather than explicit requirements — acceptable for framework tooling.
