# Quickstart: BDD Verification Chain

## Manual Validation Scenarios

### 1. Generate .feature Files

```bash
# Create a test feature with a simple spec
mkdir -p /tmp/test-project/specs/001-test/tests/features

# Run testify on a feature with spec.md
# (Agent-driven — testify SKILL.md generates .feature files)

# Verify output
ls /tmp/test-project/specs/001-test/tests/features/*.feature
# Expected: one or more .feature files with valid Gherkin syntax
```

### 2. Hash Integrity

```bash
# After testify generates .feature files:
bash testify-tdd.sh store-hash "/path/to/specs/001-test/tests/features"

# Verify hash stored
cat /path/to/specs/001-test/context.json | jq '.testify'
# Expected: assertion_hash, generated_at, features_dir, file_count

# Verify hash
bash testify-tdd.sh verify-hash "/path/to/specs/001-test/tests/features"
# Expected: valid

# Tamper with a .feature file
echo "  Then something else" >> /path/to/specs/001-test/tests/features/test.feature

# Re-verify hash
bash testify-tdd.sh verify-hash "/path/to/specs/001-test/tests/features"
# Expected: invalid
```

### 3. Step Coverage Verification

```bash
# With .feature files and step definitions:
bash verify-steps.sh --json /path/to/tests/features /path/to/plan.md
# Expected: JSON with status PASS (all defined) or BLOCKED (some undefined)
```

### 4. Step Quality Analysis

```bash
# With step definitions written:
bash verify-step-quality.sh --json /path/to/tests/step_definitions python
# Expected: JSON with quality assessment per step
```

### 5. BDD Framework Scaffolding

```bash
# With a plan.md specifying Python + pytest:
bash setup-bdd.sh --json /path/to/tests/features /path/to/plan.md
# Expected: pytest-bdd installed, directories created
```

### 6. Pre-commit Hook

```bash
# Stage a modified .feature file without re-running testify:
git add specs/001-test/tests/features/modified.feature
git commit -m "test"
# Expected: ASSERTION INTEGRITY CHECK FAILED — commit blocked
```

## BATS Test Execution

```bash
# Run all tests
bats tests/bash/

# Run specific test suites
bats tests/bash/testify-tdd.bats
bats tests/bash/verify-steps.bats
bats tests/bash/verify-step-quality.bats
bats tests/bash/setup-bdd.bats
bats tests/bash/pre-commit-hook.bats
```
