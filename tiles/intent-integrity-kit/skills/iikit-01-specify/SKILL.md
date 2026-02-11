---
name: iikit-01-specify
description: Create feature specification from natural language description
---

# Intent Integrity Kit Specify

Create or update a feature specification from a natural language feature description.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Constitution Loading (REQUIRED)

Before ANY action, load and internalize the project constitution:

1. Read constitution:
   ```bash
   cat CONSTITUTION.md 2>/dev/null || echo "NO_CONSTITUTION"
   ```

2. If file doesn't exist:
   ```
   WARNING: Project constitution not found at CONSTITUTION.md

   Proceeding without constitution.
   Recommendation: Run /iikit-00-constitution first to define project principles.
   ```

3. If exists, parse all principles, constraints, and governance rules.

## Execution Flow

The text the user typed after `/iikit-01-specify` **is** the feature description.

### 1. Generate Branch Name

Analyze the feature description and create a 2-4 word short name:
- Use action-noun format when possible (e.g., "user-auth", "fix-payment-timeout")
- Preserve technical terms and acronyms (OAuth2, API, JWT, etc.)
- Keep it concise but descriptive

Examples:
- "I want to add user authentication" -> "user-auth"
- "Implement OAuth2 integration for the API" -> "oauth2-api-integration"
- "Create a dashboard for analytics" -> "analytics-dashboard"

### 2. Create Feature Branch and Directory

#### 2.1 Branch Creation Decision

Before creating a feature branch, check context and ask user:

1. **Check current branch**:
   ```bash
   git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-git"
   ```

2. **Decide whether to prompt**:
   - If already on a feature branch (matches `^[0-9]{3}-`): suggest skipping branch creation
   - If on main/master/develop: suggest creating a new branch (default)

3. **Ask user** (with context-aware default):
   ```
   Create feature branch? [Y/n]
   - Y (default): Create new branch 'NNN-feature-name'
   - n: Stay on current branch, create feature directory only
   ```

4. **If user declines branch creation** (answers 'n', 'no', or 'skip'):
   - Add `--skip-branch` flag to the script

#### 2.2 Run Feature Creation Script

**Unix/macOS/Linux:**
```bash
# With branch creation (default):
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/create-new-feature.sh --json "$ARGUMENTS" --short-name "your-short-name"

# Without branch creation (if user declined):
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/create-new-feature.sh --json --skip-branch "$ARGUMENTS" --short-name "your-short-name"
```

**Windows (PowerShell):**
```powershell
# With branch creation (default):
pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/create-new-feature.ps1 -Json "$ARGUMENTS" -ShortName "your-short-name"

# Without branch creation (if user declined):
pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/create-new-feature.ps1 -Json -SkipBranch "$ARGUMENTS" -ShortName "your-short-name"
```

Parse the JSON output for `BRANCH_NAME`, `SPEC_FILE`, and `FEATURE_NUM`.

**IMPORTANT**: Only run this script ONCE per feature. The JSON output contains the paths you need.

### 3. Load Spec Template

Read [spec-template.md](../iikit-core/templates/spec-template.md) to understand required sections.

### 4. Generate Specification

Follow this execution flow:

1. Parse user description from Input
   - If empty:
     ```
     ERROR: No feature description provided.

     Usage: /iikit-01-specify <feature description>
     Example: /iikit-01-specify Add user authentication with OAuth2 support
     ```

2. Extract key concepts from description
   - Identify: actors, actions, data, constraints

3. For unclear aspects:
   - Make informed guesses based on context and industry standards
   - Only mark with `[NEEDS CLARIFICATION: specific question]` if:
     - The choice significantly impacts feature scope or user experience
     - Multiple reasonable interpretations exist with different implications
     - No reasonable default exists
   - **LIMIT: Maximum 3 [NEEDS CLARIFICATION] markers total**
   - Prioritize clarifications by impact: scope > security/privacy > user experience > technical details

4. Fill User Scenarios & Testing section
   - Each user story must be INDEPENDENTLY TESTABLE
   - Assign priorities (P1, P2, P3) to each story

5. Generate Functional Requirements
   - Each requirement must be testable
   - Use reasonable defaults for unspecified details

6. Define Success Criteria
   - Create measurable, technology-agnostic outcomes
   - Include quantitative and qualitative measures

7. Identify Key Entities (if data involved)

### 5. Write Specification

Write to `SPEC_FILE` using the template structure.

### 6. Phase Separation Validation (REQUIRED)

Before finalizing, scan the draft specification for implementation details that belong in `/iikit-03-plan`:

**Check for violations - specification MUST NOT mention:**
- Programming languages (Python, JavaScript, TypeScript, Go, Rust, Java, C#, etc.)
- Frameworks (React, Django, Express, Spring, Rails, FastAPI, Next.js, etc.)
- Databases (PostgreSQL, MySQL, MongoDB, SQLite, Redis, DynamoDB, etc.)
- Infrastructure (Docker, Kubernetes, AWS, GCP, Azure, Terraform, etc.)
- Specific libraries or packages (lodash, pandas, axios, etc.)
- API implementation details (REST endpoints, GraphQL schemas, gRPC)
- File structures or code organization
- Data schemas or table definitions
- Architecture patterns (microservices, monolith, serverless)

**Allowed technical terms** (these describe WHAT, not HOW):
- Domain concepts (authentication, authorization, encryption)
- User-facing features (search, filter, export, import)
- Data concepts (user profile, order, transaction)
- Performance requirements (response time, throughput) - but not implementation

**If violations found:**
```
+---------------------------------------------------------------+
|  PHASE SEPARATION VIOLATION DETECTED                          |
+---------------------------------------------------------------+
|  Specification contains implementation details:               |
|  - [list each violation]                                      |
|                                                               |
|  Implementation decisions belong in /iikit-03-plan.           |
|  Specification defines WHAT users need, not HOW to build it.  |
+---------------------------------------------------------------+
|  ACTION: Removing implementation details...                   |
+---------------------------------------------------------------+
```

**Auto-fix:** Rewrite violating sections to be implementation-agnostic:
- "Store in PostgreSQL database" -> "Persist data reliably"
- "Build REST API endpoints" -> "Expose functionality to external systems"
- "Use React for the frontend" -> "Provide web-based user interface"
- "Response time under 200ms" -> "Users experience responsive interactions"

Re-validate after fixes until no violations remain.

### 7. Create Spec Quality Checklist

Generate a checklist file at `FEATURE_DIR/checklists/requirements.md`:

```markdown
# Specification Quality Checklist: [FEATURE NAME]

**Purpose**: Validate specification completeness and quality before planning
**Created**: [DATE]
**Feature**: [Link to spec.md]

## Content Quality

- [ ] No implementation details (languages, frameworks, APIs)
- [ ] Focused on user value and business needs
- [ ] Written for non-technical stakeholders
- [ ] All mandatory sections completed

## Requirement Completeness

- [ ] No [NEEDS CLARIFICATION] markers remain
- [ ] Requirements are testable and unambiguous
- [ ] Success criteria are measurable
- [ ] Success criteria are technology-agnostic
- [ ] All acceptance scenarios are defined
- [ ] Edge cases are identified
- [ ] Scope is clearly bounded
- [ ] Dependencies and assumptions identified

## Feature Readiness

- [ ] All functional requirements have clear acceptance criteria
- [ ] User scenarios cover primary flows
- [ ] Feature meets measurable outcomes defined in Success Criteria
- [ ] No implementation details leak into specification

## Notes

- Items marked incomplete require spec updates before `/iikit-02-clarify` or `/iikit-03-plan`
```

### 8. Handle Clarifications

If `[NEEDS CLARIFICATION]` markers remain (max 3):

Present each question in this format:

```markdown
## Question [N]: [Topic]

**Context**: [Quote relevant spec section]

**What we need to know**: [Specific question]

**Suggested Answers**:

| Option | Answer | Implications |
|--------|--------|--------------|
| A      | [First answer] | [Impact] |
| B      | [Second answer] | [Impact] |
| C      | [Third answer] | [Impact] |
| Custom | Provide your own | [Instructions] |

**Your choice**: _[Wait for user response]_
```

### 9. Report Completion

Output:
- Branch name
- Spec file path
- Checklist results
- Readiness for next phase (`/iikit-02-clarify` or `/iikit-03-plan`)

## Guidelines

### Quick Guidelines

- Focus on **WHAT** users need and **WHY**
- Avoid HOW to implement (no tech stack, APIs, code structure)
- Written for business stakeholders, not developers

### Success Criteria Guidelines

Success criteria must be:
1. **Measurable**: Include specific metrics
2. **Technology-agnostic**: No frameworks, languages, databases
3. **User-focused**: Describe outcomes from user/business perspective
4. **Verifiable**: Can be tested without knowing implementation

**Good examples**:
- "Users can complete checkout in under 3 minutes"
- "System supports 10,000 concurrent users"
- "95% of searches return results in under 1 second"

**Bad examples**:
- "API response time is under 200ms" (too technical)
- "Database can handle 1000 TPS" (implementation detail)

## Semantic Diff on Re-run

**If spec.md already exists**, perform semantic diff before overwriting:

### 1. Detect Existing Artifact
```bash
test -f "$SPEC_FILE" && echo "EXISTING_SPEC_FOUND"
```

### 2. If Existing Spec Found

1. **Read and parse existing spec.md**
2. **Extract semantic elements**:
   - User story count and titles
   - Requirement IDs and descriptions
   - Success criteria
   - Key entities

3. **Compare with new content**:
   ```
   +-----------------------------------------------------+
   |  SEMANTIC DIFF: spec.md                             |
   +-----------------------------------------------------+
   |  User Stories:                                      |
   |    + Added: US4 "Export Tasks"                      |
   |    ~ Changed: US2 title updated                     |
   |    - Removed: None                                  |
   |                                                     |
   |  Requirements:                                      |
   |    + Added: FR-011, FR-012                          |
   |    ~ Changed: FR-003 description modified           |
   |    - Removed: FR-008 (verify intentional)           |
   |                                                     |
   |  Success Criteria:                                  |
   |    + Added: SC-008                                  |
   |    ~ Changed: None                                  |
   |    - Removed: None                                  |
   +-----------------------------------------------------+
   |  DOWNSTREAM IMPACT:                                 |
   |  ! plan.md may need updates (new requirements)      |
   |  ! tasks.md may need regeneration                   |
   |  ! checklists may be invalidated                    |
   +-----------------------------------------------------+
   ```

4. **Ask for confirmation**:
   - "Proceed with these changes? (yes/no)"
   - If user declines, preserve existing spec

### 3. Downstream Impact Warning

If changes detected, warn about affected artifacts:
- Removed requirements -> tasks may reference deleted items
- Changed requirements -> plan may be inconsistent
- New requirements -> tasks.md needs regeneration

## Next Steps

After completing the specification:

1. **Recommended**: Run `/iikit-02-clarify` to resolve ambiguities
   - Identifies underspecified areas you may have missed
   - Asks targeted questions (max 5) to improve spec quality
   - Especially valuable for complex features

2. **Required**: Run `/iikit-03-plan` to create the technical implementation plan

Suggest to user:
```
Specification complete! Next steps:
- /iikit-02-clarify - (Recommended) Resolve any ambiguities and improve spec quality
- /iikit-03-plan - Create technical implementation plan
```
