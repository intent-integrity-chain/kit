# Tests for setup-bdd.ps1 (T052 - BDD Verification Chain)

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:SetupBddScript = Join-Path $Global:ScriptsDir "setup-bdd.ps1"

    function script:New-PlanFile {
        param(
            [string]$Path,
            [string]$Content
        )
        Set-Content -Path $Path -Value $Content -Encoding utf8
    }
}

# =============================================================================
# Framework detection from plan.md
# =============================================================================

Describe "setup-bdd.ps1 - Framework detection" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "detects pytest-bdd from Python + pytest plan" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
# Implementation Plan

## Technical Context

**Language/Version**: Python 3.12
**Testing**: pytest, pytest-bdd
"@

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.framework | Should -Be "pytest-bdd"
        $parsed.language | Should -Be "python"
    }

    It "detects behave from Python + behave plan" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
# Implementation Plan

## Technical Context

**Language/Version**: Python 3.11
**Testing**: behave
"@

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.framework | Should -Be "behave"
        $parsed.language | Should -Be "python"
    }

    It "detects @cucumber/cucumber from JavaScript plan" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
# Implementation Plan

## Technical Context

**Language/Version**: TypeScript 5.x
**Primary Dependencies**: Express
**Testing**: @cucumber/cucumber, Jest
"@

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.framework | Should -Be "@cucumber/cucumber"
        $parsed.language | Should -Be "javascript"
    }

    It "detects godog from Go plan" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
# Implementation Plan

## Technical Context

**Language/Version**: Go 1.22
**Testing**: godog, go test
"@

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.framework | Should -Be "godog"
        $parsed.language | Should -Be "go"
    }

    It "detects cucumber-jvm-maven from Java + Maven plan" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
# Implementation Plan

## Technical Context

**Language/Version**: Java 21
**Build**: Maven (pom.xml)
**Testing**: JUnit 5, Cucumber
"@

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.framework | Should -Be "cucumber-jvm-maven"
        $parsed.language | Should -Be "java"
    }

    It "detects cucumber-rs from Rust plan" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
# Implementation Plan

## Technical Context

**Language/Version**: Rust 1.75
**Testing**: cucumber-rs
"@

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.framework | Should -Be "cucumber-rs"
        $parsed.language | Should -Be "rust"
    }

    It "detects reqnroll from C# plan" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
# Implementation Plan

## Technical Context

**Language/Version**: C# .NET 8
**Testing**: Reqnroll, NUnit
"@

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.framework | Should -Be "reqnroll"
        $parsed.language | Should -Be "csharp"
    }
}

# =============================================================================
# SCAFFOLDED response - directory creation
# =============================================================================

Describe "setup-bdd.ps1 - Scaffolding" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "creates features and step_definitions directories" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Language/Version**: Python 3.12
**Testing**: pytest-bdd
"@

        $featuresDir = Join-Path $script:TestDir "tests/features"
        $result = & $script:SetupBddScript --json $featuresDir $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json

        $parsed.status | Should -Be "SCAFFOLDED"
        Test-Path $featuresDir -PathType Container | Should -Be $true
        Test-Path (Join-Path $script:TestDir "tests/step_definitions") -PathType Container | Should -Be $true
    }

    It "includes directories_created in SCAFFOLDED response" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Testing**: pytest-bdd
"@

        $featuresDir = Join-Path $script:TestDir "tests/features"
        $result = & $script:SetupBddScript --json $featuresDir $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json

        $parsed.directories_created | Should -Not -BeNullOrEmpty
        $parsed.directories_created.Count | Should -BeGreaterThan 0
    }
}

# =============================================================================
# ALREADY_SCAFFOLDED - idempotency
# =============================================================================

Describe "setup-bdd.ps1 - Idempotency" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns ALREADY_SCAFFOLDED on second run" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Testing**: pytest-bdd
"@

        $featuresDir = Join-Path $script:TestDir "tests/features"

        # First run: scaffold
        & $script:SetupBddScript --json $featuresDir $planFile 2>&1 | Out-Null

        # Second run: should be ALREADY_SCAFFOLDED
        $result = & $script:SetupBddScript --json $featuresDir $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.status | Should -Be "ALREADY_SCAFFOLDED"
    }

    It "ALREADY_SCAFFOLDED has empty directories_created" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Testing**: pytest-bdd
"@

        $featuresDir = Join-Path $script:TestDir "tests/features"

        # First run
        & $script:SetupBddScript --json $featuresDir $planFile 2>&1 | Out-Null

        # Second run
        $result = & $script:SetupBddScript --json $featuresDir $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.directories_created.Count | Should -Be 0
    }

    It "ALREADY_SCAFFOLDED has empty packages_installed" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Testing**: pytest-bdd
"@

        $featuresDir = Join-Path $script:TestDir "tests/features"

        # First run
        & $script:SetupBddScript --json $featuresDir $planFile 2>&1 | Out-Null

        # Second run
        $result = & $script:SetupBddScript --json $featuresDir $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.packages_installed.Count | Should -Be 0
    }
}

# =============================================================================
# NO_FRAMEWORK mode
# =============================================================================

Describe "setup-bdd.ps1 - NO_FRAMEWORK mode" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns NO_FRAMEWORK when no tech stack detected" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
# Implementation Plan

## Summary

This is a documentation-only feature with no code.
"@

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.status | Should -Be "NO_FRAMEWORK"
    }

    It "framework is null in NO_FRAMEWORK JSON" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content "# Plan with no tech stack"

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.framework | Should -BeNullOrEmpty
    }

    It "language is unknown in NO_FRAMEWORK mode" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content "# Plan with no tech stack"

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.language | Should -Be "unknown"
    }

    It "includes a message in NO_FRAMEWORK mode" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content "# Plan with no tech stack"

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.message | Should -Match "No BDD framework detected"
    }

    It "still creates directories even without framework" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content "# Plan with no tech stack"

        $featuresDir = Join-Path $script:TestDir "tests/features"
        & $script:SetupBddScript --json $featuresDir $planFile 2>&1 | Out-Null

        Test-Path $featuresDir -PathType Container | Should -Be $true
        Test-Path (Join-Path $script:TestDir "tests/step_definitions") -PathType Container | Should -Be $true
    }

    It "handles missing plan.md gracefully" {
        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") (Join-Path $script:TestDir "nonexistent-plan.md") 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.status | Should -Be "NO_FRAMEWORK"
    }
}

# =============================================================================
# JSON output schema validation
# =============================================================================

Describe "setup-bdd.ps1 - JSON output schema" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "SCAFFOLDED has all required fields" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Testing**: pytest-bdd
"@

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $result | Should -Match '"status"'
        $result | Should -Match '"framework"'
        $result | Should -Match '"language"'
        $result | Should -Match '"directories_created"'
        $result | Should -Match '"packages_installed"'
        $result | Should -Match '"config_files_created"'
    }

    It "NO_FRAMEWORK has required fields" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content "# Docs only"

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $result | Should -Match '"status"'
        $result | Should -Match '"framework"'
        $result | Should -Match '"language"'
        $result | Should -Match '"message"'
    }

    It "output is valid JSON for SCAFFOLDED" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Testing**: pytest-bdd
"@

        $output = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        { $output.Trim() | ConvertFrom-Json } | Should -Not -Throw
    }

    It "output is valid JSON for NO_FRAMEWORK" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content "# Docs only"

        $output = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        { $output.Trim() | ConvertFrom-Json } | Should -Not -Throw
    }

    It "config_files_created is empty array in SCAFFOLDED" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Testing**: pytest-bdd
"@

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.config_files_created.Count | Should -Be 0
    }
}

# =============================================================================
# Exit code behavior
# =============================================================================

Describe "setup-bdd.ps1 - Exit codes" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "SCAFFOLDED returns exit code 0" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Testing**: behave
"@

        & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It "ALREADY_SCAFFOLDED returns exit code 0" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Testing**: behave
"@

        $featuresDir = Join-Path $script:TestDir "tests/features"
        & $script:SetupBddScript --json $featuresDir $planFile 2>&1 | Out-Null

        & $script:SetupBddScript --json $featuresDir $planFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It "NO_FRAMEWORK returns exit code 0" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content "# Docs only"

        & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}

# =============================================================================
# Argument validation
# =============================================================================

Describe "setup-bdd.ps1 - Argument validation" {
    It "fails when features-dir argument is missing" {
        { & $script:SetupBddScript --json 2>&1 } | Should -Throw
    }

    It "fails when plan-file argument is missing" {
        { & $script:SetupBddScript --json "/tmp/somedir" 2>&1 } | Should -Throw
    }
}

# =============================================================================
# Human-readable output (non-JSON mode)
# =============================================================================

Describe "setup-bdd.ps1 - Human-readable output" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "SCAFFOLDED prints framework info in text mode" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Testing**: pytest-bdd
"@

        $result = & $script:SetupBddScript (Join-Path $script:TestDir "tests/features") $planFile *>&1 | Out-String
        $result | Should -Match "pytest-bdd"
        $result | Should -Match "Scaffolded"
    }

    It "NO_FRAMEWORK prints warning in text mode" {
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content "# Docs only"

        $result = & $script:SetupBddScript (Join-Path $script:TestDir "tests/features") $planFile *>&1 | Out-String
        $result | Should -Match "WARNING"
        $result | Should -Match "No BDD framework detected"
    }
}

# =============================================================================
# Package installation (requires real package managers)
# =============================================================================

Describe "setup-bdd.ps1 - Package installation" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "attempts pip install for pytest-bdd when pip is available" {
        # Install into isolated temp dir via pip --target
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Testing**: pytest-bdd
"@
        # Create a venv to isolate the install
        $venvDir = Join-Path $script:TestDir ".venv"
        python3 -m venv $venvDir 2>&1 | Out-Null
        $env:PATH = (Join-Path $venvDir "bin") + [System.IO.Path]::PathSeparator + $env:PATH

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile *>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.packages_installed | Should -Contain "pytest-bdd"

        # Cleanup venv
        $env:PATH = ($env:PATH -split [System.IO.Path]::PathSeparator | Where-Object { $_ -ne (Join-Path $venvDir "bin") }) -join [System.IO.Path]::PathSeparator
    }

    It "attempts npm install for @cucumber/cucumber when npm is available" {
        # npm install --save-dev is local to the test dir
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanFile -Path $planFile -Content @"
## Technical Context
**Testing**: @cucumber/cucumber
"@
        # Init package.json so npm install works locally
        Push-Location $script:TestDir
        npm init -y 2>&1 | Out-Null
        Pop-Location

        $result = & $script:SetupBddScript --json (Join-Path $script:TestDir "tests/features") $planFile *>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.packages_installed | Should -Contain "@cucumber/cucumber"
    }
}
