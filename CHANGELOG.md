# Changelog

## v1.6.0

- **Bugfix skill**: New `/iikit-bugfix` utility skill for reporting and fixing bugs without the full specify/clarify/plan/checklist workflow. Creates structured `bugs.md` records, generates fix tasks, and integrates with GitHub Issues (inbound import and outbound creation). Cross-platform scripts (bash + PowerShell).
- **Multi-feature support**: Sticky feature selection via `.specify/active-feature` file that survives session restarts. Detection cascade: active-feature file > `SPECIFY_FEATURE` env > git branch > single feature auto-select.
- **SessionStart hooks**: Hooks for Gemini CLI and OpenCode that set terminal title and load context on session start.
- **Tessl eval integration**: `/iikit-03-plan` now queries Tessl evals for tech selection and dashboard metrics.
- **Bug detection in specify**: `/iikit-01-specify` now detects bug-fix-like descriptions and suggests redirecting to `/iikit-bugfix`.
- **Post-fix GitHub comments**: `/iikit-08-implement` comments on linked GitHub issues after completing bug fix tasks.
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

- **Live kanban dashboard**: The implement skill (`/iikit-08-implement`) now automatically launches a browser-based kanban board via `npx iikit-kanban`. Watch user stories move through Todo / In Progress / Done columns as the AI agent checks off tasks in real time. Dark/light theme, collapsible task lists, integrity badges. Gracefully skips if Node.js is not available.

## v1.1.0

- **Git hooks for assertion integrity**: Pre-commit hook blocks tampered assertions. Post-commit hook stores hashes as tamper-resistant git notes. Defense-in-depth with dual-layer verification — works agent-agnostically because git triggers the hooks, not the agent.

## v1.0.x

- Initial release with 10-phase specification-driven workflow, assertion integrity hashing, constitution enforcement, TDD support, and cross-platform (Bash + PowerShell) scripts.
