# Upstream: Vanilla Intent Integrity Kit Relationship

This directory documents the relationship between Intent Integrity Kit Skills and the upstream [GitHub Intent Integrity Kit](https://github.com/github/intent-integrity-kit) project.

## Contents

| File | Purpose |
|------|---------|
| `MIGRATION-ANALYSIS.md` | Analysis of vanilla intent-integrity-kit structure and migration strategy |
| `TEST-REPORT.md` | Comparison test results (happy path + adversarial) |
| `TEST-GUIDE.md` | How to run your own comparison tests |

## Upstream Version Tracking

| Intent Integrity Kit Skills Version | Based on Intent Integrity Kit Version | Date |
|------------------------|---------------------------|------|
| 1.0.0 | v0.0.90 | 2026-01-27 |

## Migration Strategy

When a new version of vanilla intent-integrity-kit is released:

1. **Diff analysis**: Compare new version against `MIGRATION-ANALYSIS.md`
2. **Identify changes**: New commands, modified templates, changed behavior
3. **Update skills**: Apply changes to `.claude/skills/iikit-*/`
4. **Update scripts**: Apply changes to `.specify/scripts/bash/`
5. **Test**: Run comparison tests per `TEST-GUIDE.md`
6. **Document**: Update `TEST-REPORT.md` with new results

## Future: Automatic Migration

This directory will house tooling for automatic migration when new intent-integrity-kit versions are released:

```
upstream/
  MIGRATION-ANALYSIS.md    # Current analysis
  TEST-REPORT.md           # Test results
  TEST-GUIDE.md            # Testing instructions
  README.md                # This file

  # Future additions:
  migrate.sh               # Auto-migration script
  version-history/         # Historical version analyses
  diff-reports/            # Version-to-version diffs
```

## Links

- **Upstream**: https://github.com/github/intent-integrity-kit
- **Intent Integrity Kit CLI**: `uv tool install specify-cli`
- **Template Version**: Spec Kit Template v0.0.90
