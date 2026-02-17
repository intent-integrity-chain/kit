<!--
SYNC IMPACT REPORT
Version: 0.0.0 -> 1.0.0
Change Type: MAJOR (initial constitution)
Modified Principles: All (new)
Added Sections: Core Principles, Quality Standards,
  Development Workflow, Governance
Removed Sections: None
Templates Requiring Updates: None
Follow-up TODOs: None
-->

# Intent Integrity Kit Constitution

## Core Principles

### I. Skills-First

All functionality MUST be delivered as AI agent skills.
Skills are the primary interface for users; scripts and
utilities exist only to support skill execution.

- Every user-facing capability MUST have a corresponding
  skill
- Skills MUST be self-contained with clear inputs and
  outputs
- Supporting scripts MUST be invocable from skills, not
  used directly by users

**Rationale**: Users interact with AI agents, not command
lines. Skills provide the natural interface for AI-assisted
development workflows.

### II. Multi-Agent Compatibility

Skills MUST work across multiple AI coding assistants
without modification.

- Primary source of truth: `.claude/skills/`
- Other agents MUST use symlinks to the primary location
- Skill instructions MUST NOT use agent-specific features
- Agent instruction files MUST be kept in sync via symlinks

**Rationale**: Users choose their AI assistant; the
framework should not lock them into a specific tool.

### III. Cross-Platform Parity (NON-NEGOTIABLE)

Every script MUST have equivalent implementations for both
Unix and Windows.

- Both implementations MUST produce identical outputs for
  identical inputs
- New script functionality MUST NOT be merged without both
  platform implementations

**Rationale**: Development teams use mixed environments.
Platform-specific features create friction and exclusion.

### IV. Phase Separation (NON-NEGOTIABLE)

Strict boundaries MUST be maintained between workflow
phases and their artifacts.

- Constitution: governance principles only
- Specification: user needs and requirements only
- Plan: technical decisions only
- Tasks: actionable work items only

Skills MUST validate phase boundaries and reject or
auto-fix violations.

**Rationale**: Clean separation enables independent
evolution of governance, requirements, and implementation
without cascading changes.

### V. Self-Validating Skills

Each skill MUST check its own prerequisites before
execution.

- Skills MUST NOT assume previous phases completed
- Missing prerequisites MUST produce clear error messages
  with remediation steps
- Skills MUST NOT proceed with partial or invalid inputs

**Rationale**: Users invoke skills directly; each skill
must stand alone in validating its execution context.

## Quality Standards

### Documentation

- Agent instruction files MUST be kept current with all
  features
- Skills MUST include inline documentation of inputs,
  outputs, and behavior
- Breaking changes MUST be documented with migration
  guidance

### Error Handling

- All errors MUST use consistent format with remediation
- Scripts MUST return appropriate exit codes
- Warnings MUST include actionable recommendations

### Testing

- Scripts MUST be tested on both platforms before merge
- Workflow changes MUST include end-to-end validation

## Development Workflow

### Specification-Driven Development

This project uses its own specification-driven workflow.
Features MUST follow the numbered phases in order.
Skipping phases is NOT permitted without explicit
justification.

### Review Requirements

- All changes MUST maintain cross-platform parity
- All changes MUST preserve multi-agent compatibility
- Phase separation violations MUST be rejected

## Governance

This constitution supersedes all other development
practices for this project.

**Amendment Process**:
1. Propose change with rationale
2. Assess impact on existing skills and workflows
3. Update affected templates and documentation
4. Increment version appropriately

**Version Policy**:
- MAJOR: Principle removal or incompatible redefinition
- MINOR: New principle or significant expansion
- PATCH: Clarification or minor refinement

**Compliance**: All skill changes MUST be validated against
these principles. Violations MUST be resolved before merge.

**Version**: 1.0.0 | **Ratified**: 2026-02-17 | **Last Amended**: 2026-02-17
