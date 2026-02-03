# Intent Integrity Kit Skills Framework Principles

> **Note**: This document defines the development principles for the **intent-integrity-kit-skills framework itself**.
> Projects that use this framework create their own constitution via `/iikit-00-constitution`,
> stored at `CONSTITUTION.md`.

<!--
SYNC IMPACT REPORT
Version: 0.0.0 -> 1.0.0
Change Type: MAJOR (initial constitution)
Modified Principles: All (new)
Added Sections: Core Principles, Quality Standards, Development Workflow, Governance
Templates Requiring Updates: None
Follow-up TODOs: None
-->

## Core Principles

### I. Skills-First

All functionality MUST be delivered as AI agent skills. Skills are the primary interface
for users; scripts and utilities exist only to support skill execution.

- Every user-facing capability MUST have a corresponding skill
- Skills MUST be self-contained with clear inputs and outputs
- Skills MUST NOT require external CLI tools for core functionality
- Supporting scripts MUST be invocable from skills, not used directly by users

**Rationale**: Users interact with AI agents, not command lines. Skills provide
the natural interface for AI-assisted development workflows.

### II. Multi-Agent Compatibility

Skills MUST work across multiple AI coding assistants without modification.

- Primary source of truth: `.claude/skills/`
- Other agents (Codex, Gemini, OpenCode) MUST use symlinks to the primary location
- Skill instructions MUST NOT use agent-specific features or syntax
- Agent instruction files MUST be kept in sync via symlinks to `AGENTS.md`

**Rationale**: Users choose their AI assistant; the framework should not lock them
into a specific tool.

### III. Cross-Platform Parity (NON-NEGOTIABLE)

Every script MUST have equivalent implementations for both Unix and Windows.

- Bash scripts in `.claude/skills/iikit-core/scripts/bash/`
- PowerShell scripts in `.claude/skills/iikit-core/scripts/powershell/`
- Both MUST produce identical outputs for identical inputs
- Skills MUST include platform detection and call appropriate script variant
- New script functionality MUST NOT be merged without both implementations

**Rationale**: Development teams use mixed environments. Platform-specific features
create friction and exclusion.

### IV. Phase Separation (NON-NEGOTIABLE)

Strict boundaries MUST be maintained between workflow phases and their artifacts.

- **Constitution**: Governance principles only; NO technology decisions
- **Specification**: User needs and requirements only; NO implementation details
- **Plan**: Technical decisions only; NO governance rules
- **Tasks**: Actionable work items only; derived from plan and spec

Skills MUST validate phase boundaries and reject or auto-fix violations.

**Rationale**: Clean separation enables independent evolution of governance,
requirements, and implementation without cascading changes.

### V. Self-Validating Skills

Each skill MUST check its own prerequisites before execution.

- Skills MUST NOT assume previous phases completed successfully
- Missing prerequisites MUST produce clear error messages with remediation
- Error messages MUST include the specific command to resolve the issue
- Skills MUST NOT proceed with partial or invalid inputs

**Rationale**: Users invoke skills directly; each skill must stand alone in
validating its execution context.

## Quality Standards

### Documentation

- README MUST be kept current with all features
- Skills MUST include inline documentation of inputs, outputs, and behavior
- Breaking changes MUST be documented with migration guidance

### Error Handling

- All errors MUST use consistent format: `ERROR: <message>` with remediation
- Warnings MUST use format: `WARNING: <message>` with recommendation
- Scripts MUST return appropriate exit codes

### Testing

- Scripts MUST be tested on both platforms before merge
- Workflow changes MUST include end-to-end validation

## Development Workflow

### Specification-Driven Development

This project uses its own specification-driven workflow. Features MUST follow:

0. Constitution (if governance changes needed)
1. Specification (requirements and acceptance criteria)
2. Clarification (resolve ambiguities)
3. Planning (technical approach)
4. Checklist (quality validation)
5. Testify (test specifications for TDD, if constitutionally required)
6. Task breakdown (actionable items)
7. Analyze (cross-artifact consistency)
8. Implementation (code changes)
9. Tasks to Issues (GitHub export, optional)

Skipping phases is NOT permitted without explicit justification.

### Review Requirements

- All changes MUST maintain cross-platform parity
- All changes MUST preserve multi-agent compatibility
- Phase separation violations MUST be rejected

## Governance

This constitution supersedes all other development practices for this project.

**Amendment Process**:
1. Propose change with rationale
2. Assess impact on existing skills and workflows
3. Update affected templates and documentation
4. Increment version appropriately

**Version Policy**:
- MAJOR: Principle removal or incompatible redefinition
- MINOR: New principle or significant expansion
- PATCH: Clarification or minor refinement

**Compliance**: All skill changes MUST be validated against these principles.
Violations MUST be resolved before merge.

**Version**: 1.0.0 | **Ratified**: 2025-01-31 | **Last Amended**: 2025-01-31
