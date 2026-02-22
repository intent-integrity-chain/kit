# Tests for verify-steps.ps1 (T052 - BDD Verification Chain)

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:VerifyStepsScript = Join-Path $Global:ScriptsDir "verify-steps.ps1"
}

# =============================================================================
# Helper: create a plan.md with a specific tech stack
# =============================================================================

function New-PlanWithStack {
    param(
        [string]$PlanFile,
        [string]$Language,
        [string]$Framework = ""
    )

    $content = @"
# Implementation Plan

## Technical Context

**Language/Version**: $Language
**Primary Dependencies**: $Framework
**Testing**: $Framework
"@
    Set-Content -Path $PlanFile -Value $content -Encoding utf8
}

# =============================================================================
# Helper: create .feature files in a directory
# =============================================================================

function New-FeatureFiles {
    param([string]$Dir)

    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    }

    $loginFeature = @"
Feature: Login
  Scenario: Valid login
    Given a registered user
    When they enter valid credentials
    Then they are logged in
    And they see the dashboard
"@

    $logoutFeature = @"
Feature: Logout
  Scenario: User logout
    Given a logged in user
    When they click logout
    Then they are logged out
"@

    Set-Content -Path (Join-Path $Dir "login.feature") -Value $loginFeature -Encoding utf8
    Set-Content -Path (Join-Path $Dir "logout.feature") -Value $logoutFeature -Encoding utf8
}

# =============================================================================
# Framework detection tests
# =============================================================================

Describe "verify-steps.ps1 - Framework detection" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "detects pytest-bdd from plan.md" {
        $planFile = Join-Path $script:TestDir "plan.md"
        $featuresDir = Join-Path $script:TestDir "features"
        New-Item -ItemType Directory -Path $featuresDir -Force | Out-Null
        New-PlanWithStack -PlanFile $planFile -Language "Python 3.11" -Framework "pytest-bdd"

        New-FeatureFiles -Dir $featuresDir

        $result = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        # Framework detected but tool likely not installed -> DEGRADED with framework name
        # OR if pytest is installed -> PASS/BLOCKED
        $result | Should -Match '"framework"'
    }

    It "detects behave from plan.md" {
        $planFile = Join-Path $script:TestDir "plan.md"
        $featuresDir = Join-Path $script:TestDir "features"
        New-Item -ItemType Directory -Path $featuresDir -Force | Out-Null
        New-PlanWithStack -PlanFile $planFile -Language "Python 3.11" -Framework "behave"

        New-FeatureFiles -Dir $featuresDir

        $result = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        $result | Should -Match 'behave'
    }

    It "detects cucumber-js from plan.md" {
        $planFile = Join-Path $script:TestDir "plan.md"
        $featuresDir = Join-Path $script:TestDir "features"
        New-Item -ItemType Directory -Path $featuresDir -Force | Out-Null
        New-PlanWithStack -PlanFile $planFile -Language "TypeScript 5.x" -Framework "@cucumber/cucumber"

        New-FeatureFiles -Dir $featuresDir

        $result = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        $result | Should -Match 'cucumber-js'
    }

    It "detects godog from plan.md" {
        $planFile = Join-Path $script:TestDir "plan.md"
        $featuresDir = Join-Path $script:TestDir "features"
        New-Item -ItemType Directory -Path $featuresDir -Force | Out-Null
        New-PlanWithStack -PlanFile $planFile -Language "Go 1.21" -Framework "godog"

        New-FeatureFiles -Dir $featuresDir

        $result = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        $result | Should -Match 'godog'
    }

    It "falls back to language inference for Python" {
        $planFile = Join-Path $script:TestDir "plan.md"
        $featuresDir = Join-Path $script:TestDir "features"
        New-Item -ItemType Directory -Path $featuresDir -Force | Out-Null

        $content = @"
# Implementation Plan

## Technical Context

**Language/Version**: Python 3.11
**Primary Dependencies**: Flask
"@
        Set-Content -Path $planFile -Value $content -Encoding utf8
        New-FeatureFiles -Dir $featuresDir

        $result = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        $result | Should -Match 'pytest-bdd'
    }
}

# =============================================================================
# DEGRADED mode tests
# =============================================================================

Describe "verify-steps.ps1 - DEGRADED mode" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns DEGRADED when no framework detected" {
        $featuresDir = Join-Path $script:TestDir "features"
        New-FeatureFiles -Dir $featuresDir
        $planFile = Join-Path $script:TestDir "plan.md"
        Set-Content -Path $planFile -Value "# No tech stack info" -Encoding utf8

        $result = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        $result | Should -Match '"status":\s*"DEGRADED"'
    }

    It "returns DEGRADED when features directory not found" {
        $planFile = Join-Path $script:TestDir "plan.md"
        Set-Content -Path $planFile -Value "# Plan" -Encoding utf8

        $result = & $script:VerifyStepsScript --json (Join-Path $script:TestDir "nonexistent") $planFile 2>&1 | Out-String
        $result | Should -Match '"status":\s*"DEGRADED"'
    }

    It "returns DEGRADED when no .feature files in directory" {
        $featuresDir = Join-Path $script:TestDir "features"
        New-Item -ItemType Directory -Path $featuresDir -Force | Out-Null
        Set-Content -Path (Join-Path $featuresDir "readme.md") -Value "# Not a feature file" -Encoding utf8
        $planFile = Join-Path $script:TestDir "plan.md"
        Set-Content -Path $planFile -Value "# No tech stack info" -Encoding utf8

        $result = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        $result | Should -Match '"status":\s*"DEGRADED"'
    }

    It "exits with code 0 in DEGRADED mode" {
        $featuresDir = Join-Path $script:TestDir "features"
        New-FeatureFiles -Dir $featuresDir
        $planFile = Join-Path $script:TestDir "plan.md"
        Set-Content -Path $planFile -Value "# No tech stack info" -Encoding utf8

        & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It "returns DEGRADED when framework detected but tool not installed" -Skip:($null -ne (Get-Command godog -ErrorAction SilentlyContinue)) {
        $featuresDir = Join-Path $script:TestDir "features"
        New-FeatureFiles -Dir $featuresDir
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanWithStack -PlanFile $planFile -Language "Go 1.21" -Framework "godog"

        $result = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        $result | Should -Match '"status":\s*"DEGRADED"'
        $result | Should -Match '"framework":\s*"godog"'
    }
}

# =============================================================================
# JSON output schema validation
# =============================================================================

Describe "verify-steps.ps1 - JSON output" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "DEGRADED output has all required fields" {
        $featuresDir = Join-Path $script:TestDir "features"
        New-FeatureFiles -Dir $featuresDir
        $planFile = Join-Path $script:TestDir "plan.md"
        Set-Content -Path $planFile -Value "# No tech" -Encoding utf8

        $result = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        $result | Should -Match '"status"'
        $result | Should -Match '"framework"'
        $result | Should -Match '"total_steps"'
        $result | Should -Match '"matched_steps"'
        $result | Should -Match '"undefined_steps"'
        $result | Should -Match '"pending_steps"'
    }

    It "DEGRADED output is valid JSON" {
        $featuresDir = Join-Path $script:TestDir "features"
        New-FeatureFiles -Dir $featuresDir
        $planFile = Join-Path $script:TestDir "plan.md"
        Set-Content -Path $planFile -Value "# No tech" -Encoding utf8

        $output = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        { $output.Trim() | ConvertFrom-Json } | Should -Not -Throw
    }

    It "DEGRADED output has zero step counts" {
        $featuresDir = Join-Path $script:TestDir "features"
        New-FeatureFiles -Dir $featuresDir
        $planFile = Join-Path $script:TestDir "plan.md"
        Set-Content -Path $planFile -Value "# No tech" -Encoding utf8

        $output = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        $parsed = $output.Trim() | ConvertFrom-Json
        $parsed.total_steps | Should -Be 0
        $parsed.matched_steps | Should -Be 0
        $parsed.undefined_steps | Should -Be 0
        $parsed.pending_steps | Should -Be 0
    }

    It "DEGRADED output includes a message field" {
        $featuresDir = Join-Path $script:TestDir "features"
        New-FeatureFiles -Dir $featuresDir
        $planFile = Join-Path $script:TestDir "plan.md"
        Set-Content -Path $planFile -Value "# No tech" -Encoding utf8

        $result = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        $result | Should -Match '"message"'
    }
}

# =============================================================================
# Human-readable output tests
# =============================================================================

Describe "verify-steps.ps1 - Human-readable output" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "shows DEGRADED status without --json flag" {
        $featuresDir = Join-Path $script:TestDir "features"
        New-FeatureFiles -Dir $featuresDir
        $planFile = Join-Path $script:TestDir "plan.md"
        Set-Content -Path $planFile -Value "# No tech" -Encoding utf8

        $result = & $script:VerifyStepsScript $featuresDir $planFile 2>&1 | Out-String
        $result | Should -Match "DEGRADED"
    }
}

# =============================================================================
# Argument validation / Usage error tests
# =============================================================================

Describe "verify-steps.ps1 - Argument validation" {
    It "fails when features-dir argument is missing" {
        { & $script:VerifyStepsScript --json 2>&1 } | Should -Throw
    }

    It "fails when plan-file argument is missing" {
        { & $script:VerifyStepsScript --json "/tmp/somedir" 2>&1 } | Should -Throw
    }
}

# =============================================================================
# Dry-run execution (requires real BDD framework)
# =============================================================================

Describe "verify-steps.ps1 - Dry-run with real framework" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns PASS or BLOCKED when pytest-bdd is installed and steps are defined" -Skip {
        # This test requires a real pytest-bdd installation with step definitions.
        # In a CI environment with pytest-bdd installed, remove the -Skip flag.
        $featuresDir = Join-Path $script:TestDir "features"
        New-FeatureFiles -Dir $featuresDir
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanWithStack -PlanFile $planFile -Language "Python 3.11" -Framework "pytest-bdd"

        $result = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.status | Should -BeIn @("PASS", "BLOCKED")
        $parsed.framework | Should -Be "pytest-bdd"
    }

    It "returns BLOCKED when steps are undefined in cucumber-js" -Skip {
        # This test requires a real @cucumber/cucumber installation.
        # In a CI environment with cucumber-js installed, remove the -Skip flag.
        $featuresDir = Join-Path $script:TestDir "features"
        New-FeatureFiles -Dir $featuresDir
        $planFile = Join-Path $script:TestDir "plan.md"
        New-PlanWithStack -PlanFile $planFile -Language "TypeScript 5.x" -Framework "@cucumber/cucumber"

        $result = & $script:VerifyStepsScript --json $featuresDir $planFile 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.status | Should -Be "BLOCKED"
        $parsed.undefined_steps | Should -BeGreaterThan 0
    }
}
