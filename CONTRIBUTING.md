# Contributing to Intent Integrity Kit

## Local development setup

IIKit's `SKILL.md` files invoke scripts via the tile-mount path:

```text
.tessl/plugins/tessl-labs/intent-integrity-kit/skills/<name>/scripts/...
```

That path doesn't exist in a fresh clone — Tessl populates it at install time. To dogfood unpublished changes against the local source tree, use Tessl's [local plugin development workflow](https://docs.tessl.io/create/developing-plugins-locally):

```bash
# One-time install from the local working tree
tessl install file:./tiles/intent-integrity-kit

# Or auto-reinstall on every source edit (recommended during active dev)
tessl install file:./tiles/intent-integrity-kit --watch-local
```

`tessl install file:` works exactly like a registry install but reads from the filesystem path you point it at — no publishing required. With `--watch-local`, edits under `.claude/skills/` (and the rest of `tiles/intent-integrity-kit/`) trigger an automatic reinstall.

### Why this instead of a symlink?

Prior to issue #82, a tracked symlink at `.tessl/plugins/tessl-labs/intent-integrity-kit` faked the install path by pointing at `tiles/intent-integrity-kit/`. That worked but:

- It looked vendored, tripping `dependency-management` policy reviewers.
- It broke when Tessl renamed `.tessl/tiles/` → `.tessl/plugins/` (issue #80 / PR #81).
- It bypassed Tessl's own dependency tracking — the project showed no installed plugins.

`tessl install file:` is the documented Tessl-blessed equivalent and survives future path renames.

## Tests

Bash and PowerShell tests run against the publish source tree at `tiles/intent-integrity-kit/skills/` (which symlinks to `.claude/skills/`), so they don't depend on the `tessl install file:` step. Run them with:

```bash
bash tests/run-tests.sh         # bash (bats-core required)
pwsh tests/run-tests.ps1        # PowerShell (Pester 5.x required)
```

CI runs both on every PR.

## Release

Bumps to `tiles/intent-integrity-kit/tile.json#version` trigger a publish on merge to `main`. The full release flow (PR review, merge, verify) is described in the `release` skill from `jbaruch/coding-policy`.

## Code policy

This repo loads `jbaruch/coding-policy` for PR review automation. Read `.tessl/RULES.md` for the active rule set; the gh-aw OpenAI and Anthropic reviewers gate every PR.
