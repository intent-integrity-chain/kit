# Changelog

## v2.7.2

- **27 bug fixes** from E2E testing across 12 projects (101 phases, 596 unit tests, 32 integration tests — all green).
- **Clarification badge fix**: Badges now count `- Q:` items (not session headings), and track clarifications on checklist, analyze, and tasks phases (were hardcoded to 0).
- **Dashboard resilience**: Generates without CONSTITUTION.md (was hard-fail exit 3), handles ESM projects with `type:module`.
- **Testified stage**: New `testified` feature stage between `planned` and `tasks-ready` when .feature files exist but no tasks.md.
- **Pre-commit softened**: Missing step_definitions and BDD runner dependency are now warnings, not commit blockers.
- **Bugfix task percentage**: Adding T-B bugfix tasks no longer decreases the implementation progress percentage.
- **Spec quality penalty**: Template specs with `[PLACEHOLDER]` brackets score lower to prevent false quality signals.
- **Next-step consistency**: `alt_steps` includes `/iikit-clarify` when constitution exists, status mode produces same alts as phase-based mode, `ready_for` clamped to agree with `next_step`.
- **Branch numbering**: Current branch excluded from auto-numbering; `create-new-feature.sh` warns when constitution missing.
- **Phase 00 on main**: Constitution phase no longer requires a feature branch.

## v2.7.1

## v2.7.0

## v2.6.0

- **Externalized next-step state machine**: New `next-step.sh` / `next-step.ps1` scripts serve as the single source of truth for all workflow transitions. All 12 SKILL.md files, `check-prerequisites.sh` status mode, and both session hooks (`session-context-hook.sh`, `session-context-hook-gemini.sh`) now delegate to this script instead of maintaining independent next-step logic.
- **Mandatory/optional path clarity**: Mandatory path: `00→01→02→[04 if TDD]→05→07`. Steps 03 (checklist), 06 (analyze), and 08 (tasks-to-issues) are optional and presented as `alt_steps` in JSON output.
- **Model tier in status output**: `check-prerequisites.sh --phase status --json` now includes a `model_tier` field, codified from `model-recommendations.md` (light/medium/heavy).
- **Clear recommendations**: Each transition includes `clear_before` and `clear_after` flags based on context consumption patterns (e.g., plan/implement consume heavy context → suggest `/clear` after).
- **Comprehensive test coverage**: 56 new BATS tests for `next-step.sh` covering all phase transitions, TDD branching, artifact-state fallback, clear logic, model tiers, and alt steps. Pester tests for PowerShell parity.
- **Packaging transitive dependencies**: `prepare-tile.sh` updated to ensure `next-step.sh/ps1` are distributed as transitive deps when `check-prerequisites.sh` or session hooks are present.

## v2.5.1

- **Clarify next-step fix**: Clarify now uses feature state to determine the correct next-step suggestion instead of hardcoded phase logic.

## v2.5.0

- **Generic clarify utility**: `/iikit-clarify` extracted from the numbered sequence into a standalone utility. Can run after any phase on any artifact (spec, plan, checklist, testify, tasks, or constitution). Auto-detects the most recent artifact in reverse phase order; user can override with an argument (e.g., `/iikit-clarify plan`). Per-artifact ambiguity taxonomies: spec (functional scope, domain, UX, non-functional, edge cases, terminology), plan (framework choice, architecture, trade-offs, scalability, dependency risks), checklist (threshold appropriateness, missing checks, false positives), testify (scenario precision, missing paths, Given/When/Then completeness), tasks (dependency correctness, ordering, scope, parallelization), constitution (principle clarity, threshold specificity, conflict resolution, enforcement gaps).
- **Full skill renumbering**: All downstream skills renumbered after extracting clarify. New sequence: `iikit-02-plan`, `iikit-03-checklist`, `iikit-04-testify`, `iikit-05-tasks`, `iikit-06-analyze`, `iikit-07-implement`, `iikit-08-taskstoissues`. Utilities: `iikit-core`, `iikit-clarify`, `iikit-bugfix`.
- **Dashboard clarification badges**: Pipeline nodes display `?N` amber badges when clarification sessions exist for that artifact's `## Clarifications` section. Clarify removed from pipeline as a phase node. New `countClarificationSessions()` parser function counts `### Session YYYY-MM-DD` headings per artifact.
- **Relaxed clarify prerequisites**: `check-prerequisites.sh --phase clarify` no longer requires a feature directory or spec — can clarify a constitution alone. Phase config: soft constitution, no spec/plan/tasks requirements.
- **Checklist excludes requirements.md**: `parseChecklists()` and `parseChecklistsDetailed()` now filter out `requirements.md` (spec quality checklist from `/iikit-01-specify`) to prevent falsely marking the checklist phase as complete before `/iikit-03-checklist` is actually run.

## v2.4.0

- **BDD in bugfix workflow**: When the constitution mandates TDD/BDD, `/iikit-bugfix` creates `bugfix_BUG-NNN.feature` files with Gherkin scenarios and re-hashes the features directory. `/iikit-07-implement` bugfix mode applies the full BDD verification chain when `.feature` files are present.
- **Testify enforcement across phases**: `check-prerequisites.sh` gates phases 05-08 on `.feature` file existence when TDD/BDD is mandatory. All four defense lines (skill, rule, script, hook) now enforce testify.
- **Cached TDD determination**: Constitution skill writes `tdd_determination` to `.specify/context.json` on ratification. All consumers read from cache instead of re-parsing the constitution.
- **BDD/behavior-driven detection**: Constitution scanner recognizes BDD, behavior-driven, and behaviour-driven as synonyms for TDD.
- **Dashboard refresh rule**: Always-on rule ensures dashboard regeneration after any file change in `specs/` or project root. Skills also regenerate explicitly (testify, tasks, checklist, analyze).
- **Phase separation rule**: Always-on rule enforcing no tech in constitution, no implementation in spec, no governance in plan.

## v2.3.0

- **Always-on Tessl rules**: Three `alwaysApply: true` rules loaded into agent context on every request — `assertion-integrity` (never tamper with `.feature` files or test assertions), `phase-discipline` (never code without spec/plan/tasks, never skip phases), and `constitution` (never violate `CONSTITUTION.md` principles). Adds a new defense-in-depth layer alongside skills, scripts, and git hooks.

## v2.2.0

- **Pre-commit BDD runner enforcement**: When `.feature` files exist, code commits are now mechanically gated on three checks: step definitions present, BDD runner dependency in project dep files, and `verify-steps.sh` dry-run passes. Covers all 8 supported frameworks (pytest-bdd, behave, @cucumber/cucumber, godog, cucumber-jvm-maven, cucumber-jvm-gradle, cucumber-rs, reqnroll). Agents can no longer bypass the BDD verification chain by writing plain tests.
- **`check_bdd_dependency()` utility**: New function in `common.sh` that checks language-specific dependency files (requirements.txt, package.json, go.mod, pom.xml, build.gradle, Cargo.toml, *.csproj) for the expected BDD framework.

## v2.1.0 – v2.1.6

- **PREMISE.md mandatory**: Init now requires PREMISE.md; constitution skill validates it via script.
- **Dashboard fixes**: Remove auto-reload in favor of manual refresh button; fix testify view crash, cross-link rendering, checklist/testify/analyze completion status, and active tab persistence.
- **Framework dedup**: Single `detect_framework()` in `common.sh` replaces duplicated detection logic across scripts.
- **Generator single source of truth**: Delete bundled generator; consistent `src/` path; clearer template error messages.
- **SC-XXX traceability**: Fix prose range detection for success criteria references.
- **Windows parity**: Fix 19 Pester test failures, setup-windows-links parameter handling, output stream capture.
- **CI hardening**: Move E2E tests from nightly to every push; Windows runner; skill review gate at 90% threshold.

## v2.0.0

**BREAKING** — Testify generates Gherkin `.feature` files (replaces `test-specs.md`).

- **Full BDD verification chain**: Hash integrity for `.feature` files, step coverage via dry-run (`verify-steps.sh`), step quality via AST analysis (`verify-step-quality.sh`), and framework scaffolding (`setup-bdd.sh`).
- **Static dashboard**: Replaces the server-based process with a static HTML dashboard generated by `generate-dashboard.js`.
- **Analyze skill `.feature` traceability**: Tags in `.feature` files are traced back to spec requirements.
- **Implement skill red-green-verify cycle**: Enforces BDD chain during implementation.
- **Pre-commit hook `.feature` support**: Assertion integrity checks extended to `.feature` file directories with combined hashing.
- **Gherkin template reference**: Extracted to a reference file for lint compatibility.

## v1.10.0

- **PREMISE.md**: New app-wide context document (what/who/why/domain/scope). Drafted from PRD during init, confirmed by constitution skill. All skills load it automatically.
- **No clarify question limit**: Removed the artificial 5-question cap. Clarification continues until all critical ambiguities are resolved.
- **PRD feature ordering**: Features extracted from PRD are ordered in logical implementation sequence with rationale. User confirms order before issue creation.
- **Agent-aware model suggestions**: Skills suggest the optimal model for the next phase, with agent-specific switch commands and a 2-week auto-refreshing cache.
- **Auto-close bugfix issues**: Bugfix commits include `Fixes #N` for automatic GitHub issue closure on push.
- **Feature branch merge offer**: Implement and taskstoissues skills offer to merge the feature branch (local merge, PR, or skip).
- **Feature-scoped issue titles**: Tasks-to-issues uses `[FeatureID/TaskID]` format to prevent cross-feature naming conflicts.
- **Parallel issue creation**: Tasks-to-issues dispatches issue creation via subagents for faster execution.
- **No `gh` CLI hard dependency**: All GitHub operations fall back to `curl` with the GitHub API when `gh` is unavailable.

## v1.9.0

- **Git/GitHub setup in init**: `/iikit-core init` now detects the git environment (repo, remotes, `gh` CLI) and offers git init, `gh repo create`, or clone before bootstrapping IIKit.
- **PRD seeding**: `/iikit-core init [doc]` reads an existing PRD/SDD document, extracts features, and creates labeled GitHub issues as a backlog.
- **Auto-commit per task**: `/iikit-07-implement` commits after each completed task with Conventional Commits format (`feat(<feature-id>): <task-id> <desc>`) and `iikit-feature`/`iikit-task` trailers for spec-to-commit traceability.

## v1.6.0

- **Bugfix skill**: New `/iikit-bugfix` utility skill for reporting and fixing bugs without the full specify/clarify/plan/checklist workflow. Creates structured `bugs.md` records, generates fix tasks, and integrates with GitHub Issues (inbound import and outbound creation). Cross-platform scripts (bash + PowerShell).
- **Multi-feature support**: Sticky feature selection via `.specify/active-feature` file that survives session restarts. Detection cascade: active-feature file > `SPECIFY_FEATURE` env > git branch > single feature auto-select.
- **SessionStart hooks**: Hooks for Gemini CLI and OpenCode that set terminal title and load context on session start.
- **Tessl eval integration**: `/iikit-02-plan` now queries Tessl evals for tech selection and dashboard metrics.
- **Bug detection in specify**: `/iikit-01-specify` now detects bug-fix-like descriptions and suggests redirecting to `/iikit-bugfix`.
- **Post-fix GitHub comments**: `/iikit-07-implement` comments on linked GitHub issues after completing bug fix tasks.
- **Improved skill definitions**: Conciseness improvements and progressive disclosure across all skills.
- **Unified docs**: Tile `index.md` symlinked to `README.md` for single source of truth.

## v1.5.0

- **Spec item references in clarifications**: Clarification Q&A entries now include spec item references (FR-xxx, US-x, SC-xxx) for full traceability from clarifications back to the spec items they affect.

## v1.4.1

- **Publish action migration**: Migrated to official `tesslio/publish` GitHub Action.

## v1.4.0

- **Per-feature context**: `context.json` now lives inside each feature's spec directory, enabling better isolation between features.
- **Analyze file output**: The analyze skill writes its results to a file for dashboard consumption.
- **ASCII box borders**: Fixed misaligned borders in plan and core skill output.

## v1.3.0

- **Parallel subagent execution**: The implement skill now runs independent tasks in parallel via subagents for faster execution.
- **Single source of truth**: Skills are authored once in `.claude/skills/` with symlinks for other agents.

## v1.2.0

- **Live kanban dashboard**: The implement skill (`/iikit-07-implement`) now automatically launches a browser-based kanban board via `npx iikit-kanban`. Watch user stories move through Todo / In Progress / Done columns as the AI agent checks off tasks in real time. Dark/light theme, collapsible task lists, integrity badges. Gracefully skips if Node.js is not available.

## v1.1.0

- **Git hooks for assertion integrity**: Pre-commit hook blocks tampered assertions. Post-commit hook stores hashes as tamper-resistant git notes. Defense-in-depth with dual-layer verification — works agent-agnostically because git triggers the hooks, not the agent.

## v1.0.x

- Initial release with 10-phase specification-driven workflow, assertion integrity hashing, constitution enforcement, TDD support, and cross-platform (Bash + PowerShell) scripts.
