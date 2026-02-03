# Test Guide: Intent Integrity Kit Skills

This guide explains how to test the skills-based intent-integrity-kit implementation against vanilla intent-integrity-kit.

## Prerequisites

- Claude Code installed
- `uv` package manager (for vanilla intent-integrity-kit CLI)
- Git

## Setup Test Directories

### 1. Create Vanilla Intent Integrity Kit Test Directory

```bash
# Install specify CLI (if not already installed)
uv tool install specify-cli

# Create test directory with vanilla intent-integrity-kit
specify init test-vanilla --ai claude --force
cd test-vanilla
git init
git add -A
git commit -m "Initial commit"
cd ..
```

### 2. Create Skills-Based Test Directory

```bash
# Create test directory
mkdir -p test-skills

# Copy skills bundle
cp -r .claude test-skills/
cp -r .specify test-skills/

# Initialize git
cd test-skills
git init
git add -A
git commit -m "Initial commit"
cd ..
```

## Command Naming Difference

| Vanilla Intent Integrity Kit | Skills-Based |
|-----------------|--------------|
| `/iikit-00-constitution` | `/iikit-00-constitution` |
| `/iikit-01-specify` | `/iikit-01-specify` |
| `/iikit-02-clarify` | `/iikit-02-clarify` |
| `/iikit-03-plan` | `/iikit-03-plan` |
| `/iikit-04-checklist` | `/iikit-04-checklist` |
| `/iikit-05-tasks` | `/iikit-05-tasks` |
| `/iikit-06-analyze` | `/iikit-06-analyze` |
| `/iikit-07-implement` | `/iikit-07-implement` |
| `/iikit-05-taskstoissues` | `/iikit-05-taskstoissues` |

Skills use hyphens (`-`) because Claude Code skills naming doesn't allow dots (`.`).

## Happy Path Test

Run these prompts in sequence in both test directories. Compare behavior at each step.

### Phase 1: Constitution

```
/iikit-00-constitution

Create a constitution for a simple task management CLI app with these principles:
1. Simplicity First - Keep the code simple and readable
2. Test Coverage - All features must have tests
3. CLI-First - Everything accessible via command line
```

**Verify:**
- [ ] Creates `.specify/memory/constitution.md`
- [ ] Contains principles (NO tech stack)
- [ ] Has governance section

### Phase 2: Specify

```
/iikit-01-specify I want to build a simple task management CLI that lets users
add tasks, list tasks, and mark tasks as complete. Tasks should have a title,
optional description, and status (pending/done).
```

**Verify:**
- [ ] Creates feature branch (`001-task-cli` or similar)
- [ ] Creates `specs/001-*/spec.md`
- [ ] Contains user stories with priorities
- [ ] No technology choices in spec

### Phase 3: Plan

```
/iikit-03-plan I'm building with Python 3.11 using Click for CLI and SQLite for storage
```

**Verify:**
- [ ] Creates `plan.md` with Technical Context section
- [ ] Tech stack (Python, Click, SQLite) is in plan, NOT constitution
- [ ] Creates `research.md`, `data-model.md`
- [ ] Constitution check performed

### Phase 4: Tasks

```
/iikit-05-tasks
```

**Verify:**
- [ ] Creates `tasks.md`
- [ ] Uses proper format: `- [ ] T001 [P] [US1] Description`
- [ ] Tasks trace to user stories

## Adversarial Tests

Test workflow enforcement and abuse prevention.

### Test: Skip to Plan (Should Block)

Without running specify first:
```
/iikit-03-plan Python 3.11, Click, SQLite
```

**Expected:** BLOCKED - missing prerequisite

### Test: Wrong Branch (Should Block)

On main branch (not feature branch):
```
/iikit-05-tasks
```

**Expected:** BLOCKED - invalid branch

### Test: Invalid Branch Name (Should Block)

```bash
git checkout -b invalid-no-number
```

```
/iikit-01-specify test
```

**Expected:** BLOCKED - invalid branch format

### Test: Path Traversal (Should Block)

```
/iikit-01-specify ../../../etc/passwd
```

**Expected:** BLOCKED - invalid characters

### Test: Empty Input (Partially Handled)

```
/iikit-01-specify
```

**Expected:** Should prompt for description or block

## Comparison Checklist

| Aspect | Vanilla | Skills | Match? |
|--------|---------|--------|--------|
| Constitution created | | | |
| No tech in constitution | | | |
| Spec created | | | |
| Plan with tech stack | | | |
| Tasks generated | | | |
| Prerequisites enforced | | | |
| Branch validation | | | |
| Error messages clear | | | |

## Clean Up

To reset and retest:

```bash
# Reset test directory
cd test-directory
git checkout main
git clean -fd
git branch -D 001-*  # Delete feature branches
```

## Reporting Issues

When reporting discrepancies:

1. **Missing functionality**: What vanilla does that skills don't
2. **Different behavior**: Same input, different output
3. **Improvements**: Where skills work better than vanilla
4. **Bugs**: Errors or incorrect behavior

Include:
- Command run
- Expected behavior
- Actual behavior
- Error messages (if any)
