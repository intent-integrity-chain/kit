---
alwaysApply: true
---

# Assertion Integrity

- NEVER modify `.feature` files or `test-specs.md` directly — run `/iikit-05-testify` to regenerate them
- NEVER modify test assertions to make failing tests pass — fix the production code instead
- NEVER delete or overwrite `context.json` assertion hashes — they are the integrity anchor
- If a pre-commit hook blocks your commit for hash mismatch, do NOT use `--no-verify` — re-run `/iikit-05-testify`
