# IIKit Workflow Command Reference

Display this verbatim when the user runs `/iikit-core help` or `/iikit-core` with no subcommand.

```
Utilities (run anytime)
  /iikit-core init [doc]  Initialize project (git/GitHub setup, optional PRD seeding)
  /iikit-core use         Select active feature
  /iikit-clarify          Resolve ambiguities in any artifact at any phase
  /iikit-bugfix           Report and fix bugs without full specification workflow

Phase 0: Foundation
  /iikit-00-constitution  Define governance principles

Phase 1: Specification
  /iikit-01-specify       Create feature spec

Phase 2: Planning
  /iikit-02-plan          Create implementation plan
  /iikit-03-checklist     Generate quality checklists

Phase 3: Testing (optional unless constitutionally required)
  /iikit-04-testify       Generate test specifications

Phase 4: Task Breakdown
  /iikit-05-tasks         Generate task breakdown
  /iikit-06-analyze       Validate consistency

Phase 5: Implementation
  /iikit-07-implement     Execute implementation
  /iikit-08-taskstoissues Export to GitHub Issues

Each command validates its prerequisites automatically.
/iikit-clarify can be run after any phase to resolve ambiguities in any artifact.
Run /iikit-core status to see your current progress.
```
