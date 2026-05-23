---
alwaysApply: true
---

# Assertion Integrity

- NEVER modify `.feature` files or `test-specs.md` directly — run `/iikit-04-testify` to regenerate them
- NEVER modify test assertions to make failing tests pass — fix the production code instead
- NEVER delete or overwrite `context.json` assertion hashes — they are the integrity anchor
- If a pre-commit hook blocks your commit for hash mismatch, do NOT use `--no-verify` — re-run `/iikit-04-testify`
- NEVER use `git commit --no-verify`, `git commit -n`, or any mechanism to bypass pre-commit hooks
- NEVER delete, modify, or disable IIKit's pre-commit enforcement — IIKit installs to `.git/hooks/pre-commit`, or to `.git/hooks/iikit-pre-commit` plus a chain-call when your existing hook is preserved
- To layer additional pre-commit checks (formatters, linters, secret scanners), drop executable scripts into `.git/hooks/pre-commit.d/` — they run BEFORE IIKit's assertion-integrity check, which validates the post-extension staged state and remains the final gate
- NEVER use a hook manager (lefthook, husky, pre-commit) that overwrites or renames `.git/hooks/pre-commit` — use the `pre-commit.d/` extension point instead
- NEVER use git plumbing commands (`git commit-tree`, `git mktree`) to circumvent hook enforcement
