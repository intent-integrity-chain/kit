---
alwaysApply: true
---

# Assertion Integrity

- NEVER modify `.feature` files or `test-specs.md` directly — run `/iikit-04-testify` to regenerate them
- NEVER modify test assertions to make failing tests pass — fix the production code instead
- NEVER delete or overwrite `context.json` assertion hashes — they are the integrity anchor
- If a pre-commit hook blocks your commit for hash mismatch, do NOT use `--no-verify` — re-run `/iikit-04-testify`
- NEVER use `git commit --no-verify`, `git commit -n`, or any mechanism to bypass pre-commit hooks
- NEVER delete, modify, or disable `.git/hooks/pre-commit`
- NEVER use git plumbing commands (`git commit-tree`, `git mktree`) to circumvent hook enforcement
