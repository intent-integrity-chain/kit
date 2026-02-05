---
name: iikit-00-constitution
description: Create or update project governance principles and constitution
---

# Intent Integrity Kit Constitution

Create or update the project constitution at `CONSTITUTION.md`. This file defines the governing principles, constraints, and governance rules for specification-driven development.

## Scope - What Constitution Contains

**MUST contain:**
- Project governance principles (high-level, technology-agnostic)
- Non-negotiable development rules
- Quality standards and expectations
- Amendment procedures and versioning policy
- Compliance review expectations

**MUST NOT contain:**
- Technology stack (languages, frameworks, databases) - belongs in `/iikit-03-plan`
- Implementation details - belongs in `/iikit-03-plan`
- Specific tools or versions - belongs in `/iikit-03-plan`
- API designs or data models - belongs in `/iikit-03-plan`

The constitution defines the "laws" of the project. The plan defines how to implement features within those laws.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Prerequisites Check

1. Check if constitution already exists:
   ```bash
   cat CONSTITUTION.md 2>/dev/null || echo "NO_CONSTITUTION"
   ```

2. If constitution doesn't exist, copy from [constitution-template.md](../iikit-core/templates/constitution-template.md):
   ```bash
   cp .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/templates/constitution-template.md CONSTITUTION.md
   ```

## Execution Flow

1. **Load the existing constitution** at `CONSTITUTION.md`.
   - Identify every placeholder token of the form `[ALL_CAPS_IDENTIFIER]`.
   - **IMPORTANT**: The user might require fewer or more principles than the template. Adapt accordingly.

2. **Collect/derive values for placeholders**:
   - If user input supplies a value, use it.
   - Otherwise infer from existing repo context (README, docs, prior constitution versions).
   - For governance dates:
     - `RATIFICATION_DATE` is the original adoption date (if unknown, ask or mark TODO)
     - `LAST_AMENDED_DATE` is today if changes are made
   - `CONSTITUTION_VERSION` must increment according to semantic versioning:
     - MAJOR: Backward incompatible governance/principle removals or redefinitions
     - MINOR: New principle/section added or materially expanded guidance
     - PATCH: Clarifications, wording, typo fixes, non-semantic refinements

3. **Draft the updated constitution content**:
   - Replace every placeholder with concrete text (no bracketed tokens left)
   - Preserve heading hierarchy
   - Ensure each Principle section has: succinct name, paragraph or bullet list capturing non-negotiable rules, explicit rationale
   - Ensure Governance section lists amendment procedure, versioning policy, and compliance review expectations

4. **Consistency propagation** (validate against templates if they exist):
   - Check [plan-template.md](../iikit-core/templates/plan-template.md) for constitution alignment
   - Check [spec-template.md](../iikit-core/templates/spec-template.md) for scope/requirements alignment
   - Check [tasks-template.md](../iikit-core/templates/tasks-template.md) for task categorization alignment

5. **Produce a Sync Impact Report** (prepend as HTML comment at top of constitution file):
   - Version change: old -> new
   - List of modified principles
   - Added/removed sections
   - Templates requiring updates
   - Follow-up TODOs if any placeholders deferred

6. **Validation before final output**:
   - No remaining unexplained bracket tokens
   - Version line matches report
   - Dates in ISO format YYYY-MM-DD
   - Principles are declarative, testable, and free of vague language

7. **Phase Separation Validation (REQUIRED)**:

   Before writing, scan the draft constitution for technology-specific content that belongs in `/iikit-03-plan`:

   **Check for violations - constitution MUST NOT mention:**
   - Programming languages (Python, JavaScript, TypeScript, Go, Rust, Java, C#, etc.)
   - Frameworks (React, Django, Express, Spring, Rails, FastAPI, etc.)
   - Databases (PostgreSQL, MySQL, MongoDB, SQLite, Redis, etc.)
   - Infrastructure (Docker, Kubernetes, AWS, GCP, Azure, etc.)
   - Specific libraries or packages
   - Version numbers of tools
   - File extensions tied to languages (.py, .js, .ts, etc.)
   - API specifications (REST, GraphQL, gRPC)

   **If violations found:**
   ```
   ╭─────────────────────────────────────────────────────────────────╮
   │  PHASE SEPARATION VIOLATION DETECTED                            │
   ├─────────────────────────────────────────────────────────────────┤
   │  Constitution contains technology-specific content:             │
   │  - [list each violation]                                        │
   │                                                                 │
   │  Technology decisions belong in /iikit-03-plan, not here.     │
   │  Constitution must be technology-agnostic to survive tech       │
   │  stack changes.                                                 │
   ├─────────────────────────────────────────────────────────────────┤
   │  ACTION: Removing technology references and generalizing...     │
   ╰─────────────────────────────────────────────────────────────────╯
   ```

   **Auto-fix:** Rewrite the violating sections to be technology-agnostic:
   - "Use Python" → "Use appropriate language for the domain"
   - "Store in PostgreSQL" → "Use persistent storage"
   - "Deploy with Docker" → "Use containerization when appropriate"

   Re-validate after fixes until no violations remain.

8. **Write the completed constitution** back to `CONSTITUTION.md`

9. **Initialize Git Repository (REQUIRED)**

   A intent-integrity-kit project MUST be a git repository to ensure proper project isolation.

   ```bash
   # Check if git repo exists, initialize if not
   if [ ! -d ".git" ]; then
       git init
       echo "[specify] Git repository initialized"
   fi
   ```

   **Why this is required**: Without git init, scripts like `create-new-feature.sh` may
   find a parent git repository and create files in the wrong location.

10. **Commit Constitution to Git**

    After writing the constitution, commit it to establish the project baseline:

    ```bash
    git add CONSTITUTION.md
    # Also add README if it exists
    [ -f README.md ] && git add README.md
    git commit -m "Initialize intent-integrity-kit project with constitution"
    ```

    This creates the initial commit with the project's governing document.

11. **Output final summary** to the user with:
    - New version and bump rationale
    - Git initialization status
    - Any files flagged for manual follow-up
    - Suggested next steps

## Formatting Requirements

- Use Markdown headings exactly as in the template
- Wrap long rationale lines for readability (<100 chars)
- Keep a single blank line between sections
- Avoid trailing whitespace

## Next Steps

After creating the constitution, you can:
- Run `/iikit-01-specify` to create a feature specification

The constitution will be loaded and validated by all other iikit skills.
