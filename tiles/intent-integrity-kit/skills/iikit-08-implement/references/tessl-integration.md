# Tessl Integration Reference

Detailed instructions for Tessl tile integration during implementation.

## Check Tessl Availability

**Platform Detection**:
- Unix/Linux/macOS: `command -v tessl >/dev/null 2>&1`
- Windows PowerShell: `Get-Command tessl -ErrorAction SilentlyContinue`

**If Tessl NOT Available**:
Display once and continue:
```
ℹ️ Tessl not installed. Tile-based documentation unavailable.
   Install Tessl for enhanced library documentation: https://tessl.io
```
Then proceed without Tessl.

**If Tessl Available**: Integration is **automatic and mandatory**.

## Load Tessl Context from research.md

If `/iikit-03-plan` was run with Tessl available, `research.md` contains a "Tessl Tiles" section with:
- List of installed tiles
- Available skills from skill tiles
- Technologies without tiles

**Read this section** to understand what tiles are available for implementation.

If `research.md` doesn't have a Tessl section (plan was run without Tessl), initialize tiles now:

```
mcp__tessl__status()
```

If no tiles installed, search and install for technologies in plan.md Technical Context:

```
mcp__tessl__search(query="<technology>")
mcp__tessl__install(packageName="<workspace/tile-name>")
```

## Initialize Tile Usage Tracking

Create an internal tracking structure for the completion report:
```
TESSL_USAGE = {
    "documentation_queries": [],    # Track (library, topic, task_id)
    "skills_invoked": [],           # Track (skill_name, task_ids)
    "rules_applied": false          # Set true if .tessl/RULES.md exists
}
```

Check if rules are being applied:
```bash
test -f .tessl/RULES.md && echo "RULES_ACTIVE" || echo "NO_RULES"
```

## Documentation Query Pattern

**Before implementing ANY code that uses an installed tile's library**:

1. **Identify the library and feature needed** for the current task
2. **Query the tile**:
   ```
   mcp__tessl__query_library_docs(query="<specific task context for library>")
   ```
3. **Apply patterns** from the response to implementation
4. **Track the query** in TESSL_USAGE

**Example queries by task type**:
- Creating a CLI command: `mcp__tessl__query_library_docs(query="click command with options and arguments")`
- Database connection: `mcp__tessl__query_library_docs(query="sqlite3 connection context manager")`
- Writing tests: `mcp__tessl__query_library_docs(query="pytest fixtures for database testing")`
- API endpoint: `mcp__tessl__query_library_docs(query="fastapi route with request validation")`

**Query when**:
- Starting a task that uses a library with an installed tile
- Implementing non-trivial library features
- Encountering library-related errors
- Unsure about current best practices

**Do NOT query**:
- For basic language constructs (loops, conditionals)
- For the same pattern already queried this session
- When task doesn't involve an installed tile's library

## Skill Tile Usage During Implementation

**Skill tiles** provide specialized AI commands that can automate parts of implementation.

**Before starting each task**:
1. Check if any installed skill tile is relevant to the task
2. Skills are cataloged in research.md "Available Skills" section

**Examples of skill tile usage**:
- Database migration task → invoke migration skill if installed
- API endpoint scaffolding → invoke API scaffold skill if installed
- Test generation → invoke test generation skill if installed

**Pattern for invoking a skill tile**:
```
Skill(skill="<skill-name>", args="<context from current task>")
```

**After skill invocation**:
- Integrate skill output into implementation
- Track invocation in TESSL_USAGE.skills_invoked
- Continue with manual implementation for any gaps

## Handle Tessl Failures Gracefully

- **MCP tool unavailable**: Log warning, continue without tile queries
- **Query returns no useful result**: Proceed with best knowledge
- **Tile not found**: Note in report, implement without tile guidance
- **Network issues**: Log warning, continue implementation

**Skip Tessl if**: User passes `--no-tessl` flag.

## Tessl Tile Usage Report

If Tessl was available and used during implementation, generate a usage report:

```
╭─────────────────────────────────────────────╮
│  TESSL TILE USAGE REPORT                    │
├─────────────────────────────────────────────┤
│  Documentation queries:  X                  │
│    - <library>: <topics queried>            │
│                                             │
│  Skills invoked:         X                  │
│    - /<skill-name> (task IDs)               │
│                                             │
│  Rules applied:          [Yes/No]           │
│  Tiles used:             X of Y installed   │
╰─────────────────────────────────────────────╯
```
