# Intent Integrity Kit Skills

A complete 10-phase specification-driven development workflow for AI coding assistants.

## Overview

Intent Integrity Kit provides skills that guide AI assistants through a structured development process, from defining project governance to implementing features and exporting tasks to GitHub Issues.

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

- **Phase Separation**: Strict boundaries between governance, requirements, and implementation
- **Constitution Enforcement**: All skills validate against project principles
- **TDD Support**: Generate test specs before implementation with tamper detection
- **Checklist Gating**: "Unit tests for English" validate requirements quality
- **Self-Validating**: Each skill checks its own prerequisites
- **Cross-Platform**: Bash and PowerShell support

## Quick Start

1. **Create a constitution** (optional but recommended):
   ```
   /iikit-00-constitution
   ```

2. **Specify a feature**:
   ```
   /iikit-01-specify Add user authentication with OAuth2 support
   ```

3. **Follow the workflow** through plan, tasks, and implementation.

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
    └── test-specs.md # TDD test specifications
```

## Installation

```bash
tessl install tessl-labs/intent-integrity-kit
```
