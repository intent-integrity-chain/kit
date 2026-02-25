# Script Output Contracts

All new and modified scripts produce JSON output when invoked with `--json` flag.

## verify-steps.sh

**Invocation**: `bash verify-steps.sh --json <features-dir> <plan-file>`

### Success Response

```json
{
  "status": "PASS",
  "framework": "pytest-bdd",
  "total_steps": 24,
  "matched_steps": 24,
  "undefined_steps": 0,
  "pending_steps": 0,
  "details": []
}
```

### Failure Response

```json
{
  "status": "BLOCKED",
  "framework": "pytest-bdd",
  "total_steps": 24,
  "matched_steps": 22,
  "undefined_steps": 2,
  "pending_steps": 0,
  "details": [
    {"step": "Then they see the dashboard", "file": "authentication.feature", "line": 8},
    {"step": "And the session cookie is set", "file": "authentication.feature", "line": 15}
  ]
}
```

### Degraded Response (no framework)

```json
{
  "status": "DEGRADED",
  "framework": null,
  "message": "No BDD framework detected for tech stack. Verification chain is not integral.",
  "total_steps": 0,
  "matched_steps": 0,
  "undefined_steps": 0,
  "pending_steps": 0,
  "details": []
}
```

## verify-step-quality.sh

**Invocation**: `bash verify-step-quality.sh --json <step-definitions-dir> <language>`

### Success Response

```json
{
  "status": "PASS",
  "language": "python",
  "parser": "ast",
  "total_steps": 12,
  "quality_pass": 12,
  "quality_fail": 0,
  "details": []
}
```

### Failure Response

```json
{
  "status": "BLOCKED",
  "language": "python",
  "parser": "ast",
  "total_steps": 12,
  "quality_pass": 10,
  "quality_fail": 2,
  "details": [
    {
      "step": "Then they are logged in",
      "file": "steps/auth_steps.py",
      "line": 45,
      "issue": "EMPTY_BODY",
      "severity": "FAIL"
    },
    {
      "step": "Then the error message is displayed",
      "file": "steps/auth_steps.py",
      "line": 52,
      "issue": "NO_ASSERTION",
      "severity": "FAIL",
      "body_preview": "print('checking error')"
    }
  ]
}
```

### Degraded Analysis Response

```json
{
  "status": "PASS",
  "language": "java",
  "parser": "regex",
  "parser_note": "DEGRADED_ANALYSIS: No AST parser available for Java. Using regex heuristics.",
  "total_steps": 8,
  "quality_pass": 8,
  "quality_fail": 0,
  "details": []
}
```

## setup-bdd.sh

**Invocation**: `bash setup-bdd.sh --json <features-dir> <plan-file>`

### Success Response

```json
{
  "status": "SCAFFOLDED",
  "framework": "pytest-bdd",
  "language": "python",
  "directories_created": ["tests/features", "tests/step_definitions"],
  "packages_installed": ["pytest-bdd"],
  "config_files_created": []
}
```

### Already Scaffolded Response

```json
{
  "status": "ALREADY_SCAFFOLDED",
  "framework": "pytest-bdd",
  "language": "python",
  "directories_created": [],
  "packages_installed": [],
  "config_files_created": []
}
```

### No Framework Response

```json
{
  "status": "NO_FRAMEWORK",
  "framework": null,
  "language": "unknown",
  "message": "No BDD framework detected for tech stack. Feature files will be generated without framework scaffolding."
}
```

## testify-tdd.sh (modified commands)

Existing commands retain their JSON output format. New behavior:

### extract-assertions (modified)

**Input**: Directory path (`tests/features/`) instead of file path.

**Output**: All Given/When/Then/And/But lines across all `.feature` files, sorted by filename, whitespace-normalized.

### compute-hash (modified)

**Input**: Directory path or single `.feature` file path.

**Output**: Same format — 64-char SHA-256 hex string. `NO_ASSERTIONS` if no step lines found.

### comprehensive-check (modified)

**Input**: `comprehensive-check <features-dir-or-file> <constitution-file>`

**Output**: Same JSON format with `overall_status: PASS|WARN|BLOCKED` and `block_reason`.
