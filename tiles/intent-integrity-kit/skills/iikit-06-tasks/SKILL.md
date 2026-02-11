---
name: iikit-06-tasks
description: Generate actionable task breakdown from plan and specification
---

# Intent Integrity Kit Tasks

Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts.

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

2. If exists, parse all principles - especially those affecting task ordering (e.g., TDD requirements).

## Prerequisites Check

1. Run prerequisites check:
   ```bash
   bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/check-prerequisites.sh --json
   ```

2. Parse JSON for `FEATURE_DIR` and `AVAILABLE_DOCS`.

3. If error or missing `plan.md`:
   ```
   ERROR: plan.md not found in feature directory.

   Run: /iikit-03-plan
   ```

4. **Checklist completion check** (soft gate):
   - If `FEATURE_DIR/checklists/` directory exists and contains `.md` files:
     - Parse all checklist files for `- [ ]` (unchecked) and `- [x]` (checked) items
     - If any unchecked items remain:
       ```
       WARNING: Checklists exist but are incomplete (X/Y items checked, Z%).
       Recommend running /iikit-04-checklist to resolve before proceeding.
       Continue anyway? [y/N]
       ```
     - If user declines, stop and suggest `/iikit-04-checklist`
   - If no checklists directory exists: proceed silently (checklists are optional)

## Smart Validation

**BEFORE generating tasks, perform validation:**

### Plan Completeness Gate

1. **Tech Stack Validation**:
   - Verify plan.md has Language/Version defined (not "NEEDS CLARIFICATION")
   - If missing:
     ```
     WARNING: Tech stack undefined - tasks may be too generic.

     Recommendation: Run /iikit-03-plan to define the tech stack.
     ```

2. **User Story Mapping**:
   - Extract all user stories from spec.md (P1, P2, P3...)
   - Verify each has clear acceptance criteria
   - If story lacks testable criteria:
     ```
     WARNING: US-X has no testable acceptance criteria.

     Recommendation: Add acceptance scenarios to spec.md for this user story.
     ```

3. **Dependency Pre-Analysis**:
   - Identify shared entities from data-model.md
   - Flag entities used by multiple stories (potential blockers)
   - Suggest: "Entity X used by US1, US2, US3 - recommend Phase 2 (Foundational)"

### Quality Report

```
+-----------------------------------------------+
|  PLAN READINESS REPORT                        |
+-----------------------------------------------+
|  Tech Stack:       [Defined/Missing]    [Y/N] |
|  User Stories:     X found with criteria      |
|  Shared Entities:  X (-> Foundational phase)  |
|  API Contracts:    X endpoints defined        |
|  Research Items:   X decisions documented     |
+-----------------------------------------------+
|  TASK GENERATION: [READY/NEEDS WORK]          |
+-----------------------------------------------+
```

## Execution Flow

### 1. Load Design Documents

Read from FEATURE_DIR:
- **Required**: `plan.md` (tech stack, libraries, structure), `spec.md` (user stories with priorities)
- **Optional**: `data-model.md` (entities), `contracts/` (API endpoints), `research.md` (decisions), `quickstart.md` (test scenarios)
- **Optional**: `tests/test-specs.md` (test specifications from `/iikit-05-testify`)

If `tests/test-specs.md` exists, tasks can reference specific test IDs:
- Example: "T012 [US1] Implement to pass test TS-001 and TS-002"
- This enables true TDD: tasks explicitly reference the tests they should satisfy

### 2. Tessl Convention Consultation (if tiles installed)

**Purpose**: Query installed Tessl tiles for framework conventions to improve file path generation and task ordering.

#### 2.1 Check for Installed Tiles

**Platform Detection**:
- Unix/Linux/macOS: `command -v tessl >/dev/null 2>&1`
- Windows PowerShell: `Get-Command tessl -ErrorAction SilentlyContinue`

**If Tessl NOT Available**: Skip this section silently (no message needed, plan phase already informed user).

**If Tessl Available**:
```
mcp__tessl__status()
```

If no tiles are installed, skip to task generation.

#### 2.2 Query Primary Framework Tile for Project Structure

If a tile is installed for the primary framework (e.g., React, Django, FastAPI, Express):

```
mcp__tessl__query_library_docs(query="project structure conventions for <framework>")
```

Apply conventions to:
- File path generation in tasks
- Module/package organization
- Naming conventions for files

#### 2.3 Query Testing Framework Tile for Test Organization

If a tile is installed for the testing framework (e.g., pytest, Jest, Vitest):

```
mcp__tessl__query_library_docs(query="test organization patterns for <testing-framework>")
```

Apply patterns to:
- Test file naming and location
- Test task ordering within phases
- Fixture/helper organization

#### 2.4 Document Applied Conventions

If conventions were queried and applied, note in task generation:
```
Tasks generated with Tessl conventions:
- File structure: <framework> standard layout
- Test organization: <testing-framework> patterns
```

### 3. Execute Task Generation

1. Load `plan.md` and extract tech stack, libraries, project structure
2. Load `spec.md` and extract user stories with their priorities (P1, P2, P3, etc.)
3. If `data-model.md` exists: Extract entities and map to user stories
4. If `contracts/` exists: Map endpoints to user stories
5. If `research.md` exists: Extract decisions for setup tasks
6. Generate tasks organized by user story
7. Generate dependency graph showing user story completion order
8. Create parallel execution examples per user story
9. Validate task completeness

### 4. Task Format (REQUIRED)

Every task MUST strictly follow this format:

```text
- [ ] [TaskID] [P?] [Story?] Description with file path
```

**Format Components**:

1. **Checkbox**: ALWAYS start with `- [ ]` (markdown checkbox)
2. **Task ID**: Sequential number (T001, T002, T003...) in execution order
3. **[P] marker**: Include ONLY if task is parallelizable (different files, no dependencies)
4. **[Story] label**: REQUIRED for user story phase tasks only
   - Format: [US1], [US2], [US3], etc.
   - Setup phase: NO story label
   - Foundational phase: NO story label
   - User Story phases: MUST have story label
   - Polish phase: NO story label
5. **Description**: Clear action with exact file path

**Examples**:
- CORRECT: `- [ ] T001 Create project structure per implementation plan`
- CORRECT: `- [ ] T005 [P] Implement authentication middleware in src/middleware/auth.py`
- CORRECT: `- [ ] T012 [P] [US1] Create User model in src/models/user.py`
- CORRECT: `- [ ] T014 [US1] Implement UserService in src/services/user_service.py`
- WRONG: `- [ ] Create User model` (missing ID and Story label)
- WRONG: `T001 [US1] Create model` (missing checkbox)
- WRONG: `- [ ] [US1] Create User model` (missing Task ID)

### 5. Phase Structure

- **Phase 1**: Setup (project initialization)
- **Phase 2**: Foundational (blocking prerequisites - MUST complete before user stories)
- **Phase 3+**: User Stories in priority order (P1, P2, P3...)
  - Within each story: Tests (if requested) -> Models -> Services -> Endpoints -> Integration
  - Each phase should be independently testable
- **Final Phase**: Polish & Cross-Cutting Concerns

### 6. Task Organization

**From User Stories (spec.md)** - PRIMARY ORGANIZATION:
- Each user story (P1, P2, P3...) gets its own phase
- Map all related components to their story:
  - Models needed for that story
  - Services needed for that story
  - Endpoints/UI needed for that story
  - Tests specific to that story (if requested)
- Mark story dependencies

**From Contracts**:
- Map each contract/endpoint to the user story it serves
- Each contract -> contract test task [P] before implementation

**From Data Model**:
- Map each entity to the user story(ies) that need it
- If entity serves multiple stories: Put in earliest story or Setup phase
- Relationships -> service layer tasks

**From Setup/Infrastructure**:
- Shared infrastructure -> Setup phase (Phase 1)
- Foundational/blocking tasks -> Foundational phase (Phase 2)
- Story-specific setup -> within that story's phase

### 7. Generate tasks.md

Use template structure with:
- Correct feature name from plan.md
- Phase 1: Setup tasks
- Phase 2: Foundational tasks
- Phase 3+: One phase per user story (in priority order)
- Final Phase: Polish & cross-cutting concerns
- Dependencies section
- Parallel execution examples
- Implementation strategy section (MVP first, incremental delivery)

### 8. Dependency Graph Validation

**After generating tasks, validate the dependency graph:**

1. **Circular Dependency Detection**:

   Build task dependency graph and detect cycles using DFS:

   **Algorithm (DFS-based cycle detection)**:
   ```
   1. Build adjacency list from task dependencies:
      - For each task with "blockedBy: [T00X, T00Y]", add edges T00X -> task, T00Y -> task
      - For each task with "blocks: [T00X]", add edge task -> T00X

   2. Initialize:
      - visited = {} (empty set)
      - recursion_stack = {} (empty set)
      - cycles = [] (empty list)

   3. For each task_id in graph:
      if task_id not in visited:
         dfs_detect_cycle(task_id, visited, recursion_stack, path=[], cycles)

   4. dfs_detect_cycle(node, visited, rec_stack, path, cycles):
      visited.add(node)
      rec_stack.add(node)
      path.append(node)

      for neighbor in graph[node]:
         if neighbor not in visited:
            dfs_detect_cycle(neighbor, visited, rec_stack, path, cycles)
         elif neighbor in rec_stack:
            # Cycle found! Extract cycle path
            cycle_start = path.index(neighbor)
            cycle = path[cycle_start:] + [neighbor]
            cycles.append(cycle)

      rec_stack.remove(node)
      path.pop()

   5. Return cycles list
   ```

   **If cycles found**:
   ```
   ERROR: Circular dependency detected.

   CIRCULAR DEPENDENCY: T005 -> T012 -> T008 -> T005

   Tasks involved:
   - T005: [description]
   - T012: [description]
   - T008: [description]

   Resolution options:
   1. Remove one dependency to break the cycle
   2. Merge tasks if they represent the same work
   3. Reorder phases to resolve implicit dependencies

   Cannot generate tasks.md until resolved.
   ```

2. **Orphan Task Detection**:
   - Find tasks with no dependencies AND not blocking anything
   - If orphans found:
     ```
     WARNING: Orphan tasks detected: T015, T023

     These tasks have no dependencies and don't block anything.
     Verify they belong to the correct phase or add explicit dependencies.
     ```

3. **Critical Path Analysis**:
   - Identify longest dependency chain
   - Report: "Critical path: T001 -> T003 -> T012 -> T018 (4 tasks)"
   - Suggest parallelization opportunities
   - **List parallel batches** per phase so the implement skill can dispatch them directly:
     ```
     Parallel batches:
       Phase 2: [T004, T005] (no mutual deps) | [T006] (depends on T004)
       Phase 3: [T008, T009, T010] (no mutual deps) | [T011] (depends on T008)
     ```

4. **Phase Boundary Validation**:
   - Ensure no cross-phase dependencies go backwards
   - If backward dependency found:
     ```
     ERROR: Invalid phase dependency.

     T012 (Phase 3) depends on T018 (Phase 4).
     Earlier phases cannot depend on later phases.

     Resolution: Move T018 to Phase 3 or earlier, or remove the dependency.
     ```

5. **Story Independence Check**:
   - Verify each user story phase CAN be implemented independently
   - If higher-priority story depends on lower-priority:
     ```
     WARNING: Priority inversion detected.

     US2 (higher priority) depends on US3 tasks (lower priority).
     This may indicate incorrect story prioritization.

     Recommendation: Review story priorities or adjust dependencies.
     ```

### Dependency Report

```
+-----------------------------------------------+
|  DEPENDENCY GRAPH ANALYSIS                    |
+-----------------------------------------------+
|  Total Tasks:      X                          |
|  Circular Deps:    [None/X found]     [Y/N]   |
|  Orphan Tasks:     [None/X found]     [Y/!]   |
|  Critical Path:    X tasks deep               |
|  Phase Boundaries: [Valid/X violations] [Y/N] |
|  Story Independence: [Yes/No]           [Y/N] |
+-----------------------------------------------+
|  Parallel Opportunities: X task groups        |
|  Estimated Parallelism: X% speedup            |
+-----------------------------------------------+
```

## Report

Output:
- Path to generated tasks.md
- Summary:
  - Total task count
  - Task count per user story
  - Parallel opportunities identified
  - Independent test criteria for each story
  - Suggested MVP scope (typically just User Story 1)
  - Format validation confirmation

## Semantic Diff on Re-run

**If tasks.md already exists**, perform semantic diff before overwriting:

### 1. Detect Existing Tasks

If tasks.md exists with task items:

1. **Extract semantic elements**:
   - Task IDs and descriptions
   - Phase structure
   - Completion status (checked/unchecked)
   - User story assignments

2. **Preserve completion status**:
   - Tasks marked `[x]` should remain completed
   - Map old task IDs to new task IDs by description similarity

3. **Compare with new generation**:
   ```
   +-----------------------------------------------------+
   |  SEMANTIC DIFF: tasks.md                            |
   +-----------------------------------------------------+
   |  Tasks:                                             |
   |    + Added: T025-T030 (new user story US4)          |
   |    ~ Renamed: T012 description updated              |
   |    - Removed: T008 (was for deleted FR-008)         |
   |    [Y] Preserved: 15 completed tasks kept           |
   |                                                     |
   |  Phases:                                            |
   |    + Added: Phase 5 (User Story 4)                  |
   |    ~ Reordered: None                                |
   +-----------------------------------------------------+
   |  COMPLETION STATUS:                                 |
   |    Previously completed: 15 tasks                   |
   |    Mapped to new tasks: 14 tasks                    |
   |    Lost (task removed): 1 task                      |
   +-----------------------------------------------------+
   ```

### 2. Smart Merge Strategy

- **Completed tasks**: Preserve completion status where possible
- **New tasks**: Add as uncompleted
- **Removed tasks**: Warn if they were completed (work may be lost)
- **Reordered tasks**: Maintain new order, preserve completion

### 3. Warn About In-Progress Work

If significant changes affect completed tasks:
```
⚠ WARNING: 3 completed tasks would be affected by regeneration.
Completed work that may need review:
- T008 [x] Create User model (task removed)
- T012 [x] Implement auth (description changed)

Proceed anyway? (yes/no)
```

## Next Steps

After generating tasks:

1. **Recommended**: Run `/iikit-07-analyze` to validate cross-artifact consistency
   - Checks all user stories have corresponding tasks
   - Verifies all tasks trace back to requirements
   - Detects orphaned artifacts and constitution violations
   - Catches issues before implementation begins

2. **Required**: Run `/iikit-08-implement` to execute the implementation
   - Note: Requires all checklists to be 100% complete

Suggest to user:
```
Tasks generated! Next steps:
- /iikit-07-analyze - (Recommended) Validate consistency between spec, plan, and tasks
- /iikit-08-implement - Execute implementation (requires 100% checklist completion)
```
