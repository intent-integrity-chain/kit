# Research: BDD Verification Chain

**Date**: 2026-02-21

## BDD Framework Landscape

### Framework Selection by Language

Research conducted via web search and documentation review (2026-02-21).

| Language | Framework | Version | Dry-run | Strict Mode | Notes |
|----------|-----------|---------|---------|-------------|-------|
| Python (pytest) | pytest-bdd | 7.x | `pytest --collect-only` | N/A (collection only) | Most popular Python BDD |
| Python (standalone) | behave | 1.2.x | `--dry-run` | `--strict` (undefined=fail) | Strict Cucumber-compatible |
| JavaScript/TS | @cucumber/cucumber | 11.x | `--dry-run` | `--strict` (default since v8) | Official Cucumber.js |
| Go | godog | 0.14.x | `--dry-run` | `--strict` (undefined=fail) | Official Cucumber Go |
| Java (Maven) | Cucumber-JVM | 7.x | `-Dcucumber.options="--dry-run"` | `--strict` | JUnit 5 integration |
| Java (Gradle) | Cucumber-JVM | 7.x | Same via Gradle | Same | JUnit 5 integration |
| Rust | cucumber-rs | 0.22.1 | No CLI dry-run | `fail_on_skipped()` API | Requires Rust API config |
| C# | Reqnroll | 3.3.3 | `REQNROLL_DRY_RUN=true` env var | `missingOrPendingStepsOutcome: Error` in reqnroll.json | SpecFlow successor (EOL Dec 2024) |

### Decision: Framework Detection Strategy

**Decision**: Parse `plan.md` Technical Context for language keywords, fall back to file extension heuristics.

**Rationale**: plan.md is the authoritative source for tech stack (created in `/iikit-03-plan`). File extension heuristics handle cases where plan.md is ambiguous or incomplete.

**Alternatives rejected**:
- User configuration file: adds friction, contradicts auto-detection requirement
- Package manager detection (package.json, requirements.txt): reliable but slower and less direct than plan.md

## AST Parsing for Step Quality

### Decision: Delegate to Project Runtime

**Decision**: Use each language's own AST tools (Python `ast`, Node.js parsers, Go `go/ast`, etc.) invoked via the project's installed runtime.

**Rationale**: The project being tested already has the language runtime installed. Adding a separate parsing dependency would violate the "no new runtime dependencies" constraint. Each language's stdlib typically includes AST tooling.

**Alternatives rejected**:
- Tree-sitter (universal AST): powerful but requires native compilation, heavy dependency
- Regex heuristics (grep -A 20): explicitly rejected in issue #30 clarification — too fragile
- Dedicated parser binary: would need cross-compilation for all platforms

### Language-Specific Notes

**Python**: `ast` module is stdlib — zero additional dependencies. Parse function body, check for `assert` statements and `raise` exceptions.

**JavaScript/TypeScript**: `acorn` (parser) is commonly a transitive dependency of Node.js projects. For TypeScript, `ts-morph` or `@typescript-eslint/parser`. Fallback: Node.js `vm` module for basic parsing.

**Go**: `go/ast` and `go/parser` are stdlib. Can parse step files and inspect function bodies.

**Rust**: `syn` crate needed. May not be available in all Rust projects. Fallback to enhanced regex.

**Java/C#**: No convenient stdlib AST. Use enhanced regex with method body extraction. Flag as `DEGRADED_ANALYSIS`.

## Gherkin Advanced Constructs

### Decision: Include Guidance in Testify Skill

**Decision**: Testify SKILL.md includes criteria for when to use each advanced Gherkin construct.

**Rationale**: Resolved in issue #30 clarification #11. Agent writes `.feature` files (agent-only work per issue), so the skill prompt needs guidance.

**Criteria**:
- `Background:` — when 3+ scenarios share the same Given steps
- `Scenario Outline:` + `Examples:` — when scenarios differ only by input/output data
- `Rule:` — when scenarios cluster around distinct business rules (Gherkin v6+)

## Reqnroll (C#) Deep Dive

- SpecFlow reached EOL December 31, 2024
- Reqnroll is the community fork by SpecFlow's original creator (Gaspar Nagy)
- Reqnroll v3.3.3 (Jan 2026), supports .NET Framework 4.6.2+ through .NET 9.0
- Dry-run: `dotnet test -e "REQNROLL_DRY_RUN=true"` — skips step handler code
- Strict: `"missingOrPendingStepsOutcome": "Error"` in `reqnroll.json`
- Step registration: `[Binding]` class + `[Given]`/`[When]`/`[Then]` attributes

## cucumber-rs (Rust) Deep Dive

- Version 0.22.1 (Dec 2025)
- No `--dry-run` or `--strict` CLI flags
- Undefined steps reported as `Skipped` (not `Failed`)
- `fail_on_skipped()` Rust API method converts Skipped to Failed
- Test binary must compile and run — no lightweight dry-run
- Step registration: `#[given]`, `#[when]`, `#[then]` attribute macros on World methods

## Tessl Tiles

No tiles applicable — this feature is framework tooling using bash/PowerShell scripts, not a library-consuming application.
