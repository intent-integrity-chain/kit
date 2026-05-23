# Pre-Commit Hook Chaining

IIKit's pre-commit hook enforces assertion integrity. By default it lives at `.git/hooks/pre-commit`; if you had an existing pre-commit hook at install time, IIKit installs to `.git/hooks/iikit-pre-commit` and your hook chain-calls it. To layer additional checks (formatters, linters, secret scanners) without disturbing that enforcement, use the `.git/hooks/pre-commit.d/` extension point.

> **Linked worktrees / submodules**: `/iikit-core init` and `/iikit-core uninit` resolve the hooks dir via `git rev-parse --git-path hooks`, so running them from a worktree installs to (and removes from) the gitdir's `hooks/` — the main repo's `.git/hooks/` for worktrees, `.git/modules/<name>/hooks/` for submodules. All worktrees of a given repo share the same hooks dir by design; install once from any of them.

## How It Works

IIKit's pre-commit hook executes every file in `.git/hooks/pre-commit.d/` that:

- Is a regular file or symlink (not a subdirectory)
- Is executable (`chmod +x`)
- Is not a dotfile
- Is not the IIKit-provisioned `README` (no exec bit)

Files run in deterministic byte-collation order (`LC_ALL=C` sort). Each runs with no arguments — use `git diff --cached --name-only` to discover staged files. Exit non-zero to block the commit.

Extensions run **before** IIKit's assertion-integrity check. IIKit is the final gate — if an extension mutates a `.feature` file, `test-specs.md`, or `context.json` (whether a formatter accidentally reflows assertions or a hostile extension tampers deliberately), IIKit verifies the post-extension staged state and blocks the commit. Extensions are skipped only when no git repo is detected. A failing extension blocks the commit and the IIKit check does not run.

## Why Not a Hook Manager

Hook managers (lefthook, husky, pre-commit) install their own `.git/hooks/pre-commit` and either overwrite the IIKit hook or rename it to `pre-commit.old`. Either path violates the assertion-integrity rule — the IIKit enforcement must not be removed or silently disabled. Use `pre-commit.d/` instead; a single executable script there can shell out to whatever tool you prefer.

## Examples

Place these as executable files in `.git/hooks/pre-commit.d/` (no extension required).

The examples use NUL-delimited pipelines (`--name-only -z` + `xargs -0 -r`) so paths containing spaces, tabs, or newlines are handled correctly. They use `set -eu` rather than `set -euo pipefail` and wrap `grep` in `{ ... || true; }` so a successful no-op commit (no files match the regex) does not abort the script.

### Prettier on staged JS/TS

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit.d/prettier-write
set -eu
PATTERN='\.(ts|tsx|js|jsx|json|md|yml|yaml|html|css)$'
git diff --cached --name-only --diff-filter=ACMR -z \
    | { grep -zE "$PATTERN" || true; } \
    | xargs -0 -r bunx prettier --write
git diff --cached --name-only --diff-filter=ACMR -z \
    | { grep -zE "$PATTERN" || true; } \
    | xargs -0 -r git add
```

### ESLint --fix on staged sources

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit.d/eslint-fix
set -eu
PATTERN='\.(ts|tsx|js|jsx)$'
git diff --cached --name-only --diff-filter=ACMR -z \
    | { grep -zE "$PATTERN" || true; } \
    | xargs -0 -r npx eslint --fix
git diff --cached --name-only --diff-filter=ACMR -z \
    | { grep -zE "$PATTERN" || true; } \
    | xargs -0 -r git add
```

### Gitleaks secret scan

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit.d/secret-scan
exec gitleaks protect --staged --redact
```

### Spotless apply on staged Java

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit.d/spotless
set -eu
./mvnw -q spotless:apply
git diff --cached --name-only --diff-filter=ACMR -z \
    | { grep -zE '\.java$' || true; } \
    | xargs -0 -r git add
```

## Sharing Extensions Across the Team

`.git/hooks/` is per-clone and not tracked. To share extensions:

1. Commit your scripts to a tracked path like `scripts/git-hooks/`.
2. Add an onboarding step that symlinks each regular file into `.git/hooks/pre-commit.d/`:

```bash
find scripts/git-hooks -maxdepth 1 -type f -print0 \
    | while IFS= read -r -d '' hook; do
        ln -sf "../../../$hook" ".git/hooks/pre-commit.d/$(basename "$hook")"
    done
```

Run this once per fresh clone (or as part of a project bootstrap script). `-type f` skips subdirectories; NUL-delimited iteration handles filenames with any valid characters.

## Troubleshooting

- **Script doesn't run** — check `ls -la .git/hooks/pre-commit.d/` for the exec bit. Files without `chmod +x` are skipped silently.
- **Script ran but commit didn't pick up its fixes** — formatters that rewrite files in place must `git add` the modified files; otherwise the commit captures the unfixed staged version.
- **My extension modified a `.feature` file and now the commit is blocked** — IIKit verifies the post-extension staged state, so any extension-side mutation of `.feature` / `test-specs.md` / `context.json` re-triggers the hash check. Re-run `/iikit-04-testify` to regenerate hashes against the new content, or stop the extension from touching those paths.
