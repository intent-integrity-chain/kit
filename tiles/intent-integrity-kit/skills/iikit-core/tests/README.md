# Intent Integrity Kit Script Tests

This directory contains tests for the intent-integrity-kit bash and PowerShell scripts.

## Prerequisites

### Bash Tests (bats)

Install [bats-core](https://github.com/bats-core/bats-core):

```bash
# macOS
brew install bats-core

# Ubuntu/Debian
apt install bats

# npm (cross-platform)
npm install -g bats
```

Also install `jq` for JSON parsing:

```bash
# macOS
brew install jq

# Ubuntu/Debian
apt install jq
```

### PowerShell Tests (Pester)

Install [Pester 5.x](https://pester.dev/):

```powershell
Install-Module Pester -Force -SkipPublisherCheck
```

## Running Tests

### Bash Tests

```bash
# Run all bash tests
./run-tests.sh

# Run specific test file
./run-tests.sh common
./run-tests.sh testify-tdd

# Run with verbose output
./run-tests.sh -v
```

### PowerShell Tests

```powershell
# Run all PowerShell tests
./run-tests.ps1

# Run specific test file
./run-tests.ps1 common
./run-tests.ps1 testify-tdd

# With verbose output
./run-tests.ps1 -Verbose
```

## Test Structure

```
tests/
├── README.md               # This file
├── run-tests.sh            # Bash test runner
├── run-tests.ps1           # PowerShell test runner
├── fixtures/               # Test fixtures (mock files)
│   ├── constitution.md
│   ├── constitution-no-tdd.md
│   ├── constitution-forbidden-tdd.md
│   ├── spec.md
│   ├── spec-incomplete.md
│   ├── plan.md
│   ├── tasks.md
│   └── test-specs.md
├── bash/                   # Bash tests (bats)
│   ├── test_helper.bash
│   ├── common.bats
│   ├── testify-tdd.bats
│   ├── verify-test-execution.bats
│   ├── create-new-feature.bats
│   └── check-prerequisites.bats
└── powershell/             # PowerShell tests (Pester)
    ├── TestHelper.psm1
    ├── common.Tests.ps1
    ├── testify-tdd.Tests.ps1
    ├── verify-test-execution.Tests.ps1
    └── check-prerequisites.Tests.ps1
```

## Test Coverage

| Script | Bash Tests | PowerShell Tests |
|--------|------------|------------------|
| common | ✅ | ✅ |
| check-prerequisites | ✅ | ✅ |
| create-new-feature | ✅ | ❌ (manual only) |
| init-project | ❌ | ❌ |
| setup-plan | ❌ | ❌ |
| testify-tdd | ✅ | ✅ |
| update-agent-context | ❌ | ❌ |
| verify-test-execution | ✅ | ✅ |

## Writing New Tests

### Bash (bats)

```bash
#!/usr/bin/env bats

load 'test_helper'

setup() {
    setup_test_dir
}

teardown() {
    teardown_test_dir
}

@test "description of test" {
    # Arrange
    create_mock_feature

    # Act
    result=$(some_command)

    # Assert
    [[ "$result" == "expected" ]]
}
```

### PowerShell (Pester)

```powershell
BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
}

Describe "Feature" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "does something" {
        # Arrange
        New-MockFeature -TestDir $script:TestDir

        # Act
        $result = SomeFunction

        # Assert
        $result | Should -Be "expected"
    }
}
```

## CI Integration

Add to your CI workflow:

```yaml
# GitHub Actions example
jobs:
  test-scripts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install bats
        run: |
          sudo apt-get update
          sudo apt-get install -y bats jq

      - name: Run bash tests
        run: |
          cd .claude/skills/iikit-core/tests
          ./run-tests.sh

  test-scripts-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Pester
        shell: pwsh
        run: Install-Module Pester -Force -SkipPublisherCheck

      - name: Run PowerShell tests
        shell: pwsh
        run: |
          cd .claude/skills/iikit-core/tests
          ./run-tests.ps1
```
