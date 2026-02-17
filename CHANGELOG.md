# Changelog

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
