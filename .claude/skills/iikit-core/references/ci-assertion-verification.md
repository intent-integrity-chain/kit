# CI Assertion Integrity Verification

Server-side enforcement that cannot be bypassed by `--no-verify`.

## Why

The pre-commit hook validates assertion integrity client-side, but any agent with shell access can bypass it using `git commit --no-verify`. CI verification is the only enforcement that works regardless of which agent, tool, or human made the commit.

## GitHub Actions

Add this step to your PR workflow:

```yaml
- name: Verify assertion integrity
  run: bash .claude/skills/iikit-core/scripts/bash/verify-assertion-integrity.sh
```

Or with JSON output for programmatic consumption:

```yaml
- name: Verify assertion integrity
  run: |
    result=$(bash .claude/skills/iikit-core/scripts/bash/verify-assertion-integrity.sh --json)
    echo "$result"
    echo "$result" | jq -e '.status == "pass"'
```

## GitLab CI

```yaml
verify-assertions:
  script:
    - bash .claude/skills/iikit-core/scripts/bash/verify-assertion-integrity.sh
```

## Any CI

```bash
bash .claude/skills/iikit-core/scripts/bash/verify-assertion-integrity.sh
# Exit code 0 = pass, 1 = fail, 2 = missing dependencies
```

## What It Checks

- Scans all features in `specs/*/tests/features/`
- Computes SHA-256 hash of Gherkin assertion lines (Given/When/Then/And/But)
- Compares against stored hash in `specs/*/context.json`
- Fails if any hash mismatches (assertions modified without `/iikit-04-testify`)
