# Implementation Plan: BDD Verification Chain

**Branch**: `30-bdd-verification-chain` | **Date**: 2026-02-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/031-bdd-verification-chain/spec.md`

## Summary

Replace `test-specs.md` with standard Gherkin `.feature` files in the testify skill, adapt the integrity hash system (scripts + hooks) to work with multiple `.feature` files, and add three new verification scripts: step coverage (dry-run), step quality (AST analysis), and BDD framework scaffolding. Update the implement and analyze skills to enforce the BDD verification chain.

## Technical Context

**Language/Version**: Bash 4+, PowerShell 7+
**Primary Dependencies**: BATS (bash testing), Pester (PowerShell testing), jq (JSON processing) — all existing project dependencies
**Storage**: File-based — `context.json` for hash storage, git notes for tamper-resistant backup (existing pattern)
**Testing**: BATS for bash scripts, Pester for PowerShell scripts
**Target Platform**: macOS, Linux, Windows (cross-platform parity)
**Project Type**: Framework tooling (skills + scripts)
**Performance Goals**: All verification scripts complete in <5s for typical projects (<50 scenarios)
**Constraints**: No new runtime dependencies for the framework itself. Step quality AST parsing delegates to the project's own language runtime (Python, Node.js, Go, etc.)
**Scale/Scope**: Supports any number of `.feature` files per feature directory; tested with 1-50 files

## Constitution Check

*GATE: Passed*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Skills-First | PASS | All functionality exposed via skills; scripts support skills |
| II. Multi-Agent Compatibility | PASS | Skills use no agent-specific features |
| III. Cross-Platform Parity | PASS | Every script has bash + PowerShell variant |
| IV. Phase Separation | PASS | Plan contains only technical decisions |
| V. Self-Validating Skills | PASS | Each skill checks prerequisites |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Skills Layer                          │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  Testify     │  │  Implement   │  │   Analyze     │  │
│  │  SKILL.md    │  │  SKILL.md    │  │   SKILL.md    │  │
│  │  (modified)  │  │  (modified)  │  │   (modified)  │  │
│  └──────┬───┬──┘  └──┬───┬───┬──┘  └──────┬────────┘  │
│         │   │        │   │   │             │            │
├─────────┼───┼────────┼───┼───┼─────────────┼────────────┤
│         │   │  Scripts Layer                │            │
│  ┌──────┴───┴──────────┴───┴───┴──────┐    │            │
│  │  testify-tdd.sh/ps1  (modified)    │    │            │
│  │  - extract from .feature files     │    │            │
│  │  - combined hash across files      │    │            │
│  ├────────────────────────────────────┤    │            │
│  │  pre-commit-hook.sh/ps1 (modified) │    │            │
│  │  - detect .feature in staging      │    │            │
│  ├────────────────────────────────────┤    │            │
│  │  post-commit-hook.sh/ps1 (modified)│    │            │
│  │  - store .feature hash as git note │    │            │
│  ├────────────────────────────────────┤    │            │
│  │  verify-steps.sh/ps1       (NEW)  │    │            │
│  │  - framework detection             │    │            │
│  │  - dry-run + strict                │    │            │
│  ├────────────────────────────────────┤    │            │
│  │  verify-step-quality.sh/ps1 (NEW) │    │            │
│  │  - AST parsing per language        │    │            │
│  │  - Then assertion analysis         │    │            │
│  ├────────────────────────────────────┤    │            │
│  │  setup-bdd.sh/ps1          (NEW)  │    │            │
│  │  - framework install               │    │            │
│  │  - directory scaffolding           │    │            │
│  └────────────────────────────────────┘    │            │
│                                            │            │
├────────────────────────────────────────────┼────────────┤
│              Artifacts                     │            │
│  specs/NNN-feature/                        │            │
│    tests/                                  │            │
│      features/*.feature  ←── generated     │            │
│      step_definitions/*  ←── written by    │            │
│    context.json          ←── hash stored   │            │
│  refs/notes/testify      ←── git note      │            │
└────────────────────────────────────────────────────────┘
```

## Project Structure

### Documentation (this feature)

```text
specs/031-bdd-verification-chain/
  spec.md
  plan.md              # This file
  research.md          # Framework lookup table, AST parsing strategies
  data-model.md        # Entities and state transitions
  quickstart.md        # Test scenarios for manual validation
  contracts/           # JSON output contracts for new scripts
  checklists/
    requirements.md    # Spec quality checklist
  tasks.md             # Generated by /iikit-06-tasks
```

### Source Code (repository root)

```text
.claude/skills/
  iikit-05-testify/
    SKILL.md                    # Modified: .feature generation instructions
  iikit-07-analyze/
    SKILL.md                    # Modified: .feature tag traceability
  iikit-08-implement/
    SKILL.md                    # Modified: BDD chain enforcement
  iikit-core/
    scripts/
      bash/
        testify-tdd.sh          # Modified: .feature hash extraction
        pre-commit-hook.sh      # Modified: .feature file detection
        post-commit-hook.sh     # Modified: .feature file detection
        verify-steps.sh         # NEW: dry-run + strict verification
        verify-step-quality.sh  # NEW: AST step quality analysis
        setup-bdd.sh            # NEW: framework scaffolding
      powershell/
        testify-tdd.ps1         # Modified: .feature hash extraction
        pre-commit-hook.ps1     # Modified: .feature file detection
        post-commit-hook.ps1    # Modified: .feature file detection
        verify-steps.ps1        # NEW: dry-run + strict verification
        verify-step-quality.ps1 # NEW: AST step quality analysis
        setup-bdd.ps1           # NEW: framework scaffolding

tests/
  bash/
    testify-tdd.bats            # Modified: .feature file tests
    pre-commit-hook.bats        # Modified: .feature file tests
    verify-steps.bats           # NEW
    verify-step-quality.bats    # NEW
    setup-bdd.bats              # NEW
```

**Structure Decision**: This is framework tooling. All changes live in the existing `.claude/skills/` tree (scripts + skill instructions) with tests in `tests/bash/`. No new directories at the project root.

## Design Decisions

### D1. Hash Extraction — .feature File Format

**Current** (test-specs.md):
```bash
grep -E "^\*\*(Given|When|Then)\*\*:" "$test_specs_file"
```

**New** (`.feature` files):
```bash
# Glob all .feature files, sorted by name
for f in $(ls "$features_dir"/*.feature 2>/dev/null | sort); do
    grep -E "^\s*(Given|When|Then|And|But) " "$f"
done
```

Whitespace normalization: strip leading spaces, collapse internal whitespace, then hash. This ensures indentation changes don't invalidate the hash.

### D2. Path Derivation — Multi-File Support

**Current**: Single file `tests/test-specs.md` → derive `context.json` via `dirname(dirname(file))`.

**New**: Directory-based. Input is the features directory `tests/features/`. Derivation:
```
tests/features/ → tests/ → feature_dir/ → context.json
```

All commands that currently accept a file path (`test-specs.md`) will accept either:
- A directory path (`tests/features/`) — new behavior
- A single `.feature` file path — for backwards compat during transition

### D3. Pre-commit Hook — Staging Detection

**Current**: Checks `git diff --cached --name-only` for `test-specs.md`.

**New**: Checks for any `.feature` file in `tests/features/`:
```bash
git diff --cached --name-only | grep -E 'tests/features/.*\.feature$'
```

Context.json tamper defense remains the same: check if context.json is also staged to determine read mode (working tree vs HEAD).

### D4. Step Coverage Verification — Framework Detection

`verify-steps.sh` detects the BDD framework from `plan.md` tech stack and runs the appropriate dry-run command:

| Tech Stack | Framework | Dry-run Command |
|------------|-----------|-----------------|
| Python + pytest | pytest-bdd | `pytest --collect-only tests/` |
| Python + behave | behave | `behave --dry-run --strict` |
| JavaScript/TypeScript | @cucumber/cucumber | `npx cucumber-js --dry-run --strict` |
| Go | godog | `godog --strict --no-colors --dry-run` |
| Java + Maven | Cucumber-JVM | `mvn test -Dcucumber.options="--dry-run --strict"` |
| Java + Gradle | Cucumber-JVM | `gradle test -Dcucumber.options="--dry-run --strict"` |
| Rust | cucumber-rs | `cargo test` (with `fail_on_skipped()` in harness) |
| C# | Reqnroll | `dotnet test -e "REQNROLL_DRY_RUN=true"` |

Detection strategy: parse `plan.md` Technical Context section for language and dependency keywords. Falls back to file extension heuristics (`.py`, `.js`, `.go`, `.rs`, `.cs`) if plan.md is ambiguous.

When no framework matches: exit with `DEGRADED` status and warning message (FR-012).

### D5. Step Quality Analysis — AST Parsing Strategy

`verify-step-quality.sh` delegates to language-specific AST tools available in the project's runtime:

| Language | AST Tool | Invocation |
|----------|----------|------------|
| Python | `ast` module (stdlib) | `python3 -c "import ast; ..."` |
| JavaScript | `acorn` or Node.js `--check` | `node -e "const acorn = require('acorn'); ..."` |
| TypeScript | `ts-morph` or `tsc --noEmit` | `npx ts-node -e "..."` |
| Go | `go/ast` (stdlib) | `go run analyze_steps.go` (embedded) |
| Java | regex-based (no AST without JDK tooling) | grep with method body extraction |
| Rust | `syn` crate | `cargo script` or regex fallback |
| C# | Roslyn or regex fallback | `dotnet script` or regex |

**Fallback strategy**: For languages without a convenient AST tool, use enhanced regex with method body extraction. Flag as `DEGRADED_ANALYSIS` in output so the user knows quality checks are heuristic.

Analysis rules per step type:
- **Then** (assertions): FAIL if empty body, `pass`/`return`/`{}` only, no assertion keyword, or tautology
- **When** (actions): FAIL if empty body, WARN if no function call
- **Given** (setup): FAIL if empty body, WARN if no assignment or function call

### D6. BDD Framework Scaffolding

`setup-bdd.sh` creates the conventional directory structure and installs the framework:

```
tests/
  features/          # Created by setup-bdd.sh
  step_definitions/  # Created by setup-bdd.sh
```

Installation commands per framework:
| Framework | Install Command |
|-----------|----------------|
| pytest-bdd | `pip install pytest-bdd` |
| behave | `pip install behave` |
| @cucumber/cucumber | `npm install --save-dev @cucumber/cucumber` |
| godog | `go get github.com/cucumber/godog` |
| Cucumber-JVM | Add dependency to pom.xml/build.gradle |
| cucumber-rs | Add to Cargo.toml |
| Reqnroll | `dotnet add package Reqnroll.NUnit` (or xUnit/MsTest variant) |

Idempotent: re-running setup-bdd.sh on an already-scaffolded project is a no-op.

### D7. Skill Modifications — Testify

The testify SKILL.md changes:
1. **Output format**: Generate `.feature` files instead of `test-specs.md`
2. **Gherkin guidance**: Include `Background:`, `Scenario Outline:`, `Rule:` usage criteria
3. **Hash command**: Call `testify-tdd.sh store-hash "FEATURE_DIR/tests/features"` (directory, not file)
4. **Scaffolding**: Call `setup-bdd.sh` before generating files (if TDD enabled)
5. **Remove**: All references to `test-specs.md` output

### D8. Skill Modifications — Implement

The implement SKILL.md changes:
1. **TDD check**: Call `testify-tdd.sh comprehensive-check "FEATURE_DIR/tests/features" "CONSTITUTION.md"`
2. **Step definitions**: Instruct agent to write step definitions (not freeform tests)
3. **Verification chain**: After step definitions written → `verify-steps.sh` → expect RED → write code → expect GREEN → `verify-step-quality.sh`
4. **Immutability rule**: Agent MUST NOT modify `.feature` files — only step definitions and production code
5. **Gate**: Task not complete until `verify-steps.sh` and `verify-step-quality.sh` both pass

### D9. Skill Modifications — Analyze

The analyze SKILL.md changes:
1. **Tag extraction**: Parse `@FR-XXX`, `@US-XXX`, `@TS-XXX` tags from `.feature` files
2. **Coverage check**: Every FR-XXX in spec.md must have a corresponding `@FR-XXX` tag
3. **Orphan detection**: Tags referencing IDs not in spec.md are flagged
4. **Step coverage**: Optionally run `verify-steps.sh` as part of analysis

## Complexity Tracking

No constitution violations. All decisions comply with cross-platform parity (bash + PowerShell for every script), multi-agent compatibility (no agent-specific features in skills), and phase separation.
