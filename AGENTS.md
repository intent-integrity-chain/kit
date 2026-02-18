# Intent Integrity Kit

**Closing the intent-to-code chasm**

## Overview

Intent Integrity Kit (IIKit) preserves your intent from idea to implementation through specification-driven development with cryptographic verification. Compatible with Claude Code, Codex, Gemini, and OpenCode.

## Intent Integrity Kit Workflow

This project uses specification-driven development. The phases are:

**Utility:** `/iikit-core` - Initialize project, check status, select active feature, show help (run `init` before starting)
**Utility:** `/iikit-bugfix` - Report and fix bugs without full specification workflow

0. `/iikit-00-constitution` - Define project governance principles
1. `/iikit-01-specify` - Create feature specification from natural language
2. `/iikit-02-clarify` - Resolve ambiguities (max 5 questions)
3. `/iikit-03-plan` - Create technical implementation plan
4. `/iikit-04-checklist` - Generate domain-specific quality checklists
5. `/iikit-05-testify` - Generate test specifications (TDD support, optional unless constitutionally required)
6. `/iikit-06-tasks` - Generate task breakdown
7. `/iikit-07-analyze` - Validate cross-artifact consistency
8. `/iikit-08-implement` - Execute implementation
9. `/iikit-09-taskstoissues` - Export tasks to GitHub Issues

**Never skip phases.** Each `/iikit-*` command validates its prerequisites.

Read `FRAMEWORK-PRINCIPLES.md` for this framework's development principles.

## Project Structure

```text
.claude/skills/              # Development layout (source of truth)
  iikit-core/              # Core skill with scripts and templates
    scripts/bash/            # Bash scripts for all skills
    scripts/powershell/      # PowerShell scripts for Windows
    templates/               # Framework templates (do not edit)
    references/              # Shared reference docs (do not edit)
  iikit-00-constitution/   # Constitution skill
  iikit-01-specify/        # Specification skill
  ...                        # Other iikit-XX-* skills
.codex/skills/               # Symlink -> .claude/skills
.gemini/skills/              # Symlink -> .claude/skills
.opencode/skills/            # Symlink -> .claude/skills

CONSTITUTION.md              # Project governance (spec-agnostic, lives at root)

.specify/
  context.json               # Feature state between skill invocations
  active-feature             # Sticky active feature selection (survives restarts)
  evals/                     # Tessl eval results (fetched, not committed)

specs/                       # Feature specifications (created per feature)
  NNN-feature-name/
    spec.md                  # Feature specification
    plan.md                  # Implementation plan
    tasks.md                 # Task breakdown
    research.md              # Research findings
    data-model.md            # Data model
    quickstart.md            # Quick start guide
    contracts/               # API contracts
    checklists/              # Quality checklists
    tests/                   # Test specifications (created by /iikit-05-testify)
      test-specs.md          # Generated test specifications
```

> **Distribution note**: The `.claude/skills/` layout above is the development structure. In development, skills reference shared files in `iikit-core/` via `../iikit-core/` paths. During CI publish, these are copied into each skill and links are rewritten for self-containment. Use `tessl install tessl-labs/intent-integrity-kit` for correct setup — cloning the repo directly does not produce self-contained skills.

## Commands

```bash
# Make scripts executable (if needed)
chmod +x .claude/skills/iikit-core/scripts/bash/*.sh

# Check prerequisites for a feature
.claude/skills/iikit-core/scripts/bash/check-prerequisites.sh --json

# Create a new feature
.claude/skills/iikit-core/scripts/bash/create-new-feature.sh --json "Feature description"

# Select active feature (multi-feature projects)
.claude/skills/iikit-core/scripts/bash/set-active-feature.sh --json <selector>
```

## Skills Available

| Skill | Command | Description |
|-------|---------|-------------|
| Core | `/iikit-core` | Initialize project, check status, select feature, show help |
| Bugfix | `/iikit-bugfix` | Report and fix bugs without full specification workflow |
| Constitution | `/iikit-00-constitution` | Create project governance principles |
| Specify | `/iikit-01-specify` | Create feature spec from description |
| Clarify | `/iikit-02-clarify` | Resolve spec ambiguities |
| Plan | `/iikit-03-plan` | Create technical implementation plan |
| Checklist | `/iikit-04-checklist` | Generate quality checklists |
| Testify | `/iikit-05-testify` | Generate test specs (TDD support) |
| Tasks | `/iikit-06-tasks` | Generate task breakdown |
| Analyze | `/iikit-07-analyze` | Validate cross-artifact consistency |
| Implement | `/iikit-08-implement` | Execute implementation |
| Tasks to Issues | `/iikit-09-taskstoissues` | Export tasks to GitHub Issues |

## Key Concepts

### Constitution

The constitution (`CONSTITUTION.md`) is a **project artifact** created by `/iikit-00-constitution` when users adopt the framework. It defines project-specific governance principles. All skills load and validate against it. Critical gate skills (plan, analyze, implement) halt on violations.

**Note**: The framework's own development principles are in `FRAMEWORK-PRINCIPLES.md`.

### Self-Validating Skills

Each skill checks its own prerequisites. Users invoke the skill they want, get feedback if prerequisites are missing.

### File-Based State

The `.specify/context.json` file persists state between skill invocations:
- Current feature
- Available artifacts
- Clarification status
- Checklist completion

### Multi-Feature Support

When multiple features exist in `specs/`, IIKit detects the active feature using this cascade:
1. `.specify/active-feature` file (sticky, survives restarts)
2. `SPECIFY_FEATURE` env var (CI/scripts)
3. Git branch (`NNN-*` pattern)
4. Single feature auto-select

Use `/iikit-core use <feature>` to switch between features. Accepts a number (`1`), partial name (`user-auth`), or full directory name (`001-user-auth`).

### Checklist Gating

Checklists are "unit tests for English" - they validate REQUIREMENTS quality, not implementation. The implement skill gates on checklist completion.

### TDD Support (Testify)

The `/iikit-05-testify` skill generates test specifications from requirements before implementation:

- **When mandatory**: If the constitution contains TDD requirements (e.g., "test-first MUST be used"), testify is required before implementation
- **When optional**: If no TDD requirements exist, testify can be skipped
- **What it produces**: A `tests/test-specs.md` file with acceptance, contract, and validation test specifications derived from spec.md, plan.md, and data-model.md

Test specifications serve as acceptance criteria for implementation. The implement skill warns against modifying test assertions to match buggy code.

### Cross-Agent Support

Skills are stored in `.claude/skills/` with symlinks for other agents:
- `.codex/skills/` → `.claude/skills/`
- `.gemini/skills/` → `.claude/skills/`
- `.opencode/skills/` → `.claude/skills/`

Instruction files: `CLAUDE.md` and `GEMINI.md` are symlinks to this file (`AGENTS.md`).

<!-- IIKIT-TECH-START -->
<!-- Tech stack will be inserted here by /iikit-03-plan -->
<!-- IIKIT-TECH-END -->

# Tessl Rules <!-- tessl-managed -->

@.tessl/RULES.md follow the [instructions](.tessl/RULES.md)
