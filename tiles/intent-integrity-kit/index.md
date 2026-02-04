# Intent Integrity Kit

**Closing the intent-to-code chasm**

A complete specification-driven development workflow for AI coding assistants with cryptographic verification.

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

- [Intent Integrity Chain](https://github.com/jbaruch/intent-integrity-chain) - The methodology behind IIKit
