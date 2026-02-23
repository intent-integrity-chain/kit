# Tests for validate-premise.ps1

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:ValidateScript = Join-Path $Global:ScriptsDir "validate-premise.ps1"

    function script:New-GoodPremise {
        param([string]$TestDir)
        Copy-Item (Join-Path $Global:FixturesDir "premise-good.md") (Join-Path $TestDir "PREMISE.md")
    }

    function script:New-BadPremise {
        param([string]$TestDir)
        Copy-Item (Join-Path $Global:FixturesDir "premise-bad.md") (Join-Path $TestDir "PREMISE.md")
    }

    function script:New-EmptySectionsPremise {
        param([string]$TestDir)
        Copy-Item (Join-Path $Global:FixturesDir "premise-empty-sections.md") (Join-Path $TestDir "PREMISE.md")
    }
}

# =============================================================================
# PASS tests
# =============================================================================

Describe "PASS scenarios" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "validates complete PREMISE.md (PASS)" {
        New-GoodPremise -TestDir $script:TestDir

        $result = & $script:ValidateScript -Json $script:TestDir | ConvertFrom-Json
        $result.status | Should -Be "PASS"
    }

    It "passes with all 5 sections filled" {
        New-GoodPremise -TestDir $script:TestDir

        $result = & $script:ValidateScript -Json $script:TestDir | ConvertFrom-Json
        $result.sections_found | Should -Be 5
        $result.sections_required | Should -Be 5
        $result.placeholders_remaining | Should -Be 0
    }

    It "exit code 0 for PASS" {
        New-GoodPremise -TestDir $script:TestDir

        & $script:ValidateScript -Json $script:TestDir | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It "does not flag markdown links as placeholders" {
        $premisePath = Join-Path $script:TestDir "PREMISE.md"
        @"
# My Project Premise

## What
A project that uses [this link](https://example.com) for reference.

## Who
Developers who read [docs](https://docs.example.com).

## Why
To solve a real problem.

## Domain
Software development tools.

## Scope
CLI only. No web interface.
"@ | Out-File -FilePath $premisePath -Encoding utf8

        $result = & $script:ValidateScript -Json $script:TestDir | ConvertFrom-Json
        $result.status | Should -Be "PASS"
        $result.placeholders_remaining | Should -Be 0
    }
}

# =============================================================================
# FAIL tests
# =============================================================================

Describe "FAIL scenarios" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "fails when PREMISE.md missing" {
        $result = & $script:ValidateScript -Json $script:TestDir 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 1
        $result | Should -Match "not found"
    }

    It "fails when sections missing" {
        New-BadPremise -TestDir $script:TestDir

        $result = & $script:ValidateScript -Json $script:TestDir 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 1
        $result | Should -Match "FAIL"
        $result | Should -Match "Why|Domain|Scope"
    }

    It "fails when placeholders remain" {
        New-BadPremise -TestDir $script:TestDir

        # Capture the JSON line from output (may include error stream)
        $allOutput = & $script:ValidateScript -Json $script:TestDir 2>&1
        $jsonLine = ($allOutput | Where-Object { $_ -match '^\{' }) -join ''
        if ($jsonLine) {
            $parsed = $jsonLine | ConvertFrom-Json
            $parsed.placeholders_remaining | Should -BeGreaterThan 0
        }
        $LASTEXITCODE | Should -Be 1
    }

    It "exit code 1 for FAIL" {
        & $script:ValidateScript -Json $script:TestDir 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 1
    }

    It "handles PREMISE.md with only comments (empty sections)" {
        New-EmptySectionsPremise -TestDir $script:TestDir

        $allOutput = & $script:ValidateScript -Json $script:TestDir 2>&1
        $LASTEXITCODE | Should -Be 1
        ($allOutput | Out-String) | Should -Match "no content|FAIL"
    }

    It "detects placeholder tokens like [PROJECT_NAME]" {
        $premisePath = Join-Path $script:TestDir "PREMISE.md"
        @"
# [PROJECT_NAME] Premise

## What
A real description of the project.

## Who
Real users.

## Why
Real reason.

## Domain
Real domain.

## Scope
Real scope.
"@ | Out-File -FilePath $premisePath -Encoding utf8

        $allOutput = & $script:ValidateScript -Json $script:TestDir 2>&1
        $jsonLine = ($allOutput | Where-Object { $_ -match '^\{' }) -join ''
        if ($jsonLine) {
            $parsed = $jsonLine | ConvertFrom-Json
            $parsed.placeholders_remaining | Should -BeGreaterThan 0
        }
        $LASTEXITCODE | Should -Be 1
    }
}

# =============================================================================
# JSON schema tests
# =============================================================================

Describe "JSON output schema" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "JSON output has correct schema on PASS" {
        New-GoodPremise -TestDir $script:TestDir

        $result = & $script:ValidateScript -Json $script:TestDir | ConvertFrom-Json
        $result.PSObject.Properties.Name | Should -Contain "status"
        $result.PSObject.Properties.Name | Should -Contain "sections_found"
        $result.PSObject.Properties.Name | Should -Contain "sections_required"
        $result.PSObject.Properties.Name | Should -Contain "placeholders_remaining"
        $result.PSObject.Properties.Name | Should -Contain "missing_sections"
        $result.PSObject.Properties.Name | Should -Contain "details"
    }

    It "JSON output is valid JSON on missing file" {
        $allOutput = & $script:ValidateScript -Json $script:TestDir 2>&1
        $jsonLine = ($allOutput | Where-Object { $_ -match '^\{' }) -join ''
        if ($jsonLine) {
            { $jsonLine | ConvertFrom-Json } | Should -Not -Throw
        }
    }
}

# =============================================================================
# Help test
# =============================================================================

Describe "Help" {
    It "-Help shows usage" {
        $result = & $script:ValidateScript -Help | Out-String
        $result | Should -Match "Usage:"
        $result | Should -Match "-Json"
    }
}

# =============================================================================
# Section counting tests
# =============================================================================

Describe "Section counting" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "sections_found counts only present sections" {
        New-BadPremise -TestDir $script:TestDir

        $allOutput = & $script:ValidateScript -Json $script:TestDir 2>&1
        $jsonLine = ($allOutput | Where-Object { $_ -match '^\{' }) -join ''
        if ($jsonLine) {
            $parsed = $jsonLine | ConvertFrom-Json
            $parsed.sections_found | Should -Be 2
        }
    }
}
