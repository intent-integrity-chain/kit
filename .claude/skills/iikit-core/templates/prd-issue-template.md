# PRD Issue Template

Used by Step 6 (Seed backlog from PRD) when creating GitHub issues from extracted features.

## Labels

Create before issues (idempotent). Use `gh` if available, otherwise `curl` the GitHub API.
```bash
# Preferred:
gh label create feature --description "Feature extracted from PRD" --color 0E8A16 --force
gh label create iikit --description "Intent Integrity Kit" --color 1D76DB --force
```

## Issue Command

Use `gh` if available, otherwise `curl` the GitHub API (`POST /repos/{owner}/{repo}/issues`).
```bash
# Preferred:
gh issue create --title "<feature title>" --body "<body>" --label "iikit,feature"
```

## Body Template

```markdown
## Feature
<description>

## Priority
<P1/P2/P3>

## Source
Extracted from PRD: `<filename or URL>`

## Next Steps
Run `/iikit-01-specify #<this-issue>` to create a full specification.

---
*Seeded by /iikit-core init*
```
