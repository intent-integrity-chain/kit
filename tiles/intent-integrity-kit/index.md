# Intent Integrity Kit

**Closing the intent-to-code chasm**

[GitHub](https://github.com/intent-integrity-chain/kit) | [npm: iikit-kanban](https://www.npmjs.com/package/iikit-kanban)

A complete specification-driven development workflow for AI coding assistants with cryptographic verification.

## What's New in v1.2.0

- **Live kanban dashboard**: The implement skill (`/iikit-08-implement`) now automatically launches a browser-based kanban board via `npx iikit-kanban`. Watch user stories move through Todo / In Progress / Done columns as the AI agent checks off tasks in real time. Dark/light theme, collapsible task lists, integrity badges. Gracefully skips if Node.js is not available.
- **Git hooks** (v1.1.0): Pre-commit blocks tampered assertions. Post-commit stores hashes as tamper-resistant git notes. Defense-in-depth with dual-layer verification.

## Overview

Intent Integrity Kit (IIKit) preserves your intent from idea to implementation. It guides AI assistants through a structured development process while preventing circular verification - where AI modifies tests to match buggy code.

## Workflow Phases

| Phase | Skill | Purpose |
|-------|-------|---------|
| Utility | `/iikit-core` | Initialize project, check status, show help |
| 0 | `/iikit-00-constitution` | Define project governance principles |
| 1 | `/iikit-01-specify` | Create feature specification from natural language |
| 2 | `/iikit-02-clarify` | Resolve ambiguities (max 5 questions) |
| 3 | `/iikit-03-plan` | Create technical implementation plan |
| 4 | `/iikit-04-checklist` | Generate quality checklists for requirements |
| 5 | `/iikit-05-testify` | Generate test specifications (TDD support) |
| 6 | `/iikit-06-tasks` | Generate task breakdown |
| 7 | `/iikit-07-analyze` | Validate cross-artifact consistency |
| 8 | `/iikit-08-implement` | Execute implementation |
| 9 | `/iikit-09-taskstoissues` | Export tasks to GitHub Issues |

## Key Features

- **Intent Preservation**: Traces intent from idea through spec, test, and code
- **Assertion Integrity**: SHA256 hashing prevents test tampering during implementation
- **Git Hook Enforcement**: Pre-commit and post-commit hooks enforce assertion integrity agent-agnostically — works with Claude Code, Codex, Copilot, Gemini, and any other agent because git triggers them, not the agent
- **Phase Separation**: Strict boundaries between governance, requirements, and implementation
- **Constitution Enforcement**: All skills validate against project principles
- **TDD Support**: Generate test specs before implementation with tamper detection
- **Checklist Gating**: "Unit tests for English" validate requirements quality
- **Self-Validating**: Each skill checks its own prerequisites
- **Cross-Platform**: Bash and PowerShell support

## Quick Start

1. **Initialize your project**:
   ```
   /iikit-core init
   ```

2. **Create a constitution** (defines project governance):
   ```
   /iikit-00-constitution
   ```

3. **Specify a feature**:
   ```
   /iikit-01-specify Add user authentication with OAuth2 support
   ```

4. **Follow the workflow** through plan, testify, tasks, and implementation.

## Artifacts Created

```
specs/NNN-feature-name/
├── spec.md           # Feature specification
├── plan.md           # Technical implementation plan
├── tasks.md          # Task breakdown
├── research.md       # Research findings
├── data-model.md     # Entity definitions
├── quickstart.md     # Integration scenarios
├── contracts/        # API specifications
├── checklists/       # Quality checklists
└── tests/
    └── test-specs.md # TDD test specifications (hash-locked)
```

## Installation

```bash
tessl install tessl-labs/intent-integrity-kit
```

## Learn More

- [Intent Integrity Kit on GitHub](https://github.com/intent-integrity-chain/kit) - Source code, issues, and contributions
- [IIKit Kanban Board](https://github.com/intent-integrity-chain/iikit-kanban) - Live dashboard source code
- [Intent Integrity Chain](https://github.com/jbaruch/intent-integrity-chain) - The methodology behind IIKit
