# Pre-Commit Hook Chaining

IIKit's pre-commit hook enforces assertion integrity. By default it lives at `.git/hooks/pre-commit`; if you had an existing pre-commit hook at install time, IIKit installs to `.git/hooks/iikit-pre-commit` and your hook chain-calls it. To layer additional checks (formatters, linters, secret scanners) without disturbing that enforcement, use the `.git/hooks/pre-commit.d/` extension point.

## How It Works

IIKit's pre-commit hook executes every file in `.git/hooks/pre-commit.d/` that:

- Is a regular file or symlink (not a subdirectory)
- Is executable (`chmod +x`)
- Is not a dotfile
- Is not the IIKit-provisioned `README` (no exec bit)

Files run in deterministic byte-collation order (`LC_ALL=C` sort). Each runs with no arguments — use `git diff --cached --name-only` to discover staged files. Exit non-zero to block the commit.

Extensions fire on every IIKit success or no-op path: the assertion check passing, nothing relevant staged (fast-path), and the degraded "IIKit scripts not found" warning path. They are skipped only when IIKit explicitly blocks the commit, so extensions never see a partial pass.

## Why Not a Hook Manager

Hook managers (lefthook, husky, pre-commit) install their own `.git/hooks/pre-commit` and either overwrite the IIKit hook or rename it to `pre-commit.old`. Either path violates the assertion-integrity rule — the IIKit enforcement must not be removed or silently disabled. Use `pre-commit.d/` instead; a single executable script there can shell out to whatever tool you prefer.

## Examples

Place these as executable files in `.git/hooks/pre-commit.d/` (no extension required).

### Prettier on staged JS/TS

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit.d/prettier-write
set -euo pipefail
staged=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(ts|tsx|js|jsx|json|md|yml|yaml|html|css)$' || true)
[ -z "$staged" ] && exit 0
echo "$staged" | xargs bunx prettier --write
echo "$staged" | xargs git add
```

### ESLint --fix on staged sources

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit.d/eslint-fix
set -euo pipefail
staged=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(ts|tsx|js|jsx)$' || true)
[ -z "$staged" ] && exit 0
echo "$staged" | xargs npx eslint --fix
echo "$staged" | xargs git add
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
set -euo pipefail
staged=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.java$' || true)
[ -z "$staged" ] && exit 0
./mvnw -q spotless:apply
echo "$staged" | xargs git add
```

## Sharing Extensions Across the Team

`.git/hooks/` is per-clone and not tracked. To share extensions:

1. Commit your scripts to a tracked path like `scripts/git-hooks/`.
2. Add a one-line onboarding step that symlinks each into `.git/hooks/pre-commit.d/`:

```bash
for hook in scripts/git-hooks/*; do
    ln -sf "../../../$hook" ".git/hooks/pre-commit.d/$(basename "$hook")"
done
```

Run this once per fresh clone (or as part of a project bootstrap script).

## Troubleshooting

- **Script doesn't run** — check `ls -la .git/hooks/pre-commit.d/` for the exec bit. Files without `chmod +x` are skipped silently.
- **Script ran but commit didn't pick up its fixes** — formatters that rewrite files in place must `git add` the modified files; otherwise the commit captures the unfixed staged version.
- **Want to run extensions even when IIKit blocks** — by design, no. Extensions only run when IIKit's check passes or has no work to do. If IIKit blocks, fix the assertion-integrity issue first.
