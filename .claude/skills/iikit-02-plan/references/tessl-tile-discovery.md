# Tessl Tile Discovery (during planning)

## 1. Check Tessl Availability

- Unix/Linux/macOS: `command -v tessl >/dev/null 2>&1`
- Windows PowerShell: `Get-Command tessl -ErrorAction SilentlyContinue`

If not available: display info message once, continue without tiles.

## 2. Check Status

```
mcp__tessl__status()
```

## 3. Extract Technologies from Technical Context

From the drafted plan, identify: Language/Version, Primary Dependencies, Storage, Testing, any other frameworks/libraries.

## 4. Search and Install Tiles

For each technology:

1. `mcp__tessl__search(query="<technology>")`
2. Identify tile type: Documentation (has `describes`), Rules (has `rules`), Skills (has `skill`)
3. `mcp__tessl__install(packageName="<workspace/tile-name>")`
4. Document in research.md:

```markdown
## Tessl Tiles

### Installed Tiles

| Technology | Tile | Type | Version | Eval |
|------------|------|------|---------|------|

### Technologies Without Tiles

- <technology>: No tile found
```

## 5. Query Best Practices

For each installed documentation tile:
```
mcp__tessl__query_library_docs(query="best practices for <library>")
```

Incorporate findings into research.md.

## 5.5. Fetch Eval Results

For each installed tile, fetch eval scores:

```bash
bash .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/bash/fetch-tile-evals.sh --json <workspace/tile-name>
```
Windows: `pwsh .tessl/tiles/tessl-labs/intent-integrity-kit/skills/iikit-core/scripts/powershell/fetch-tile-evals.ps1 -Json <workspace/tile-name>`

- Include eval scores in the research.md Tessl Tiles table (add Eval column)
- If a technology has multiple tile options: prefer the one with higher eval score
- Full eval results are saved to `.specify/evals/` for dashboard consumption

Update the research.md table format to include eval data:

```markdown
## Tessl Tiles

### Installed Tiles

| Technology | Tile | Type | Version | Eval |
|------------|------|------|---------|------|
| FastAPI | tessl/pypi-fastapi | docs | 1.2.0 | 92% (3 scenarios) |
```

## 6. Catalog Skills

Record available skills from installed tiles for use in `/iikit-07-implement`.

## 7. Failure Handling

- Network issues / registry unavailable / auth required: log warning, continue without affected tiles
- No results: note in research.md, continue
