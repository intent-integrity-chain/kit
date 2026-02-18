# Phase Separation Rules

Content belongs in specific artifacts. Violations indicate content placed in the wrong phase.

## Constitution (MUST NOT contain)

Technology-specific content — these belong in `/iikit-03-plan`:
- Programming languages, frameworks, databases, infrastructure
- Specific libraries, packages, or version numbers
- File extensions tied to languages, API specifications

**Auto-fix**: Generalize to technology-agnostic statements.
- "Use Python" -> "Use appropriate language for the domain"
- "Store in PostgreSQL" -> "Use persistent storage"

## Specification (MUST NOT contain)

Implementation details — these belong in `/iikit-03-plan`:
- Framework/library references, API implementation details
- Database schemas, architecture patterns, code organization
- File structures or deployment specifics

**Allowed**: Domain concepts (authentication, encryption), user-facing features, data concepts, performance requirements stated as user outcomes.

**Auto-fix**: Rewrite as user-facing requirements.
- "Build REST API endpoints" -> "Expose functionality to external systems"
- "Use React for frontend" -> "Provide web-based user interface"

## Plan (MUST NOT contain)

Governance content — these belong in `/iikit-00-constitution`:
- Project-wide principles or "laws"
- Non-negotiable rules applying beyond this feature
- Team workflow or process requirements

**Auto-fix**: Replace with constitution references.
- "Always use TDD" -> "Per constitution: [reference TDD principle]"

## Validation Procedure

Scan draft for violations. If found: list each violation, explain which artifact owns that content, auto-fix, re-validate until clean.
