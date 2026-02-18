#!/usr/bin/env pwsh
# Verify that tests were actually executed and counts match expectations
# Usage: verify-test-execution.ps1 <command> <args...>

param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$TestSpecsFile,

    [Parameter(Position = 2)]
    [string]$TestOutput
)

$ErrorActionPreference = "Stop"

# Count expected tests from test-specs.md
function Get-ExpectedTestCount {
    param([string]$TestSpecsFile)

    if (-not (Test-Path $TestSpecsFile)) {
        return 0
    }

    $content = Get-Content $TestSpecsFile -Raw
    # Count TS-XXX patterns (test spec IDs)
    $matches = [regex]::Matches($content, '(?m)^###\s+TS-[0-9]+')
    return $matches.Count
}

# Parse test count from common test runner outputs
# Supports: Jest, Vitest, Pytest, Go test, Playwright, Mocha
function Get-TestOutputCounts {
    param([string]$Output)

    $passed = 0
    $failed = 0
    $total = 0

    # Jest/Vitest: "Tests: X passed, Y failed, Z total"
    if ($Output -match 'Tests:.*passed') {
        if ($Output -match '(\d+)\s+passed') {
            $passed = [int]$Matches[1]
        }
        if ($Output -match '(\d+)\s+failed') {
            $failed = [int]$Matches[1]
        }
        $total = $passed + $failed
    }
    # Pytest: "X passed" or "X passed, Y failed"
    elseif ($Output -match '\d+\s+passed') {
        if ($Output -match '(\d+)\s+passed') {
            $passed = [int]$Matches[1]
        }
        if ($Output -match '(\d+)\s+failed') {
            $failed = [int]$Matches[1]
        }
        $total = $passed + $failed
    }
    # Go test: "--- PASS:" or "--- FAIL:" counts
    elseif ($Output -match '(^ok\s|^FAIL\s|--- PASS:|--- FAIL:)') {
        $passMatches = [regex]::Matches($Output, '--- PASS:')
        $failMatches = [regex]::Matches($Output, '--- FAIL:')
        $passed = $passMatches.Count
        $failed = $failMatches.Count
        $total = $passed + $failed
    }
    # Playwright: "X passed" or "X failed"
    elseif ($Output -match '\d+\s+(passed|failed)') {
        if ($Output -match '(\d+)\s+passed') {
            $passed = [int]$Matches[1]
        }
        if ($Output -match '(\d+)\s+failed') {
            $failed = [int]$Matches[1]
        }
        $total = $passed + $failed
    }
    # Mocha: "X passing" "Y failing"
    elseif ($Output -match '\d+\s+passing') {
        if ($Output -match '(\d+)\s+passing') {
            $passed = [int]$Matches[1]
        }
        if ($Output -match '(\d+)\s+failing') {
            $failed = [int]$Matches[1]
        }
        $total = $passed + $failed
    }

    return @{
        passed = $passed
        failed = $failed
        total = $total
    }
}

# Verify test execution against expectations
function Test-Execution {
    param(
        [string]$TestSpecsFile,
        [string]$TestOutput
    )

    $expected = Get-ExpectedTestCount -TestSpecsFile $TestSpecsFile
    $results = Get-TestOutputCounts -Output $TestOutput

    $actualTotal = $results.total
    $passed = $results.passed
    $failed = $results.failed

    # Determine status
    $status = "UNKNOWN"
    $message = ""

    if ($actualTotal -eq 0) {
        $status = "NO_TESTS_RUN"
        $message = "Could not detect any test execution in output"
    }
    elseif ($failed -gt 0) {
        $status = "TESTS_FAILING"
        $message = "$failed tests failing - fix code before proceeding"
    }
    elseif ($expected -gt 0 -and $actualTotal -lt $expected) {
        $status = "INCOMPLETE"
        $message = "Only $actualTotal tests run, expected $expected from test-specs.md"
    }
    elseif ($passed -gt 0 -and $failed -eq 0) {
        $status = "PASS"
        $message = "All $passed tests passing"
    }

    return @{
        status = $status
        message = $message
        expected = $expected
        actual = @{
            total = $actualTotal
            passed = $passed
            failed = $failed
        }
    } | ConvertTo-Json -Depth 3
}

# Main
switch ($Command) {
    "count-expected" {
        if (-not $TestSpecsFile) {
            Write-Error "Usage: verify-test-execution.ps1 count-expected <test-specs-file>"
            exit 1
        }
        Get-ExpectedTestCount -TestSpecsFile $TestSpecsFile
    }
    "parse-output" {
        if (-not $TestSpecsFile) {
            Write-Error "Usage: verify-test-execution.ps1 parse-output <test-output-string>"
            exit 1
        }
        # Note: $TestSpecsFile here is actually the test output string (positional param)
        Get-TestOutputCounts -Output $TestSpecsFile | ConvertTo-Json
    }
    "verify" {
        if (-not $TestSpecsFile -or -not $TestOutput) {
            Write-Error "Usage: verify-test-execution.ps1 verify <test-specs-file> <test-output-string>"
            exit 1
        }
        Test-Execution -TestSpecsFile $TestSpecsFile -TestOutput $TestOutput
    }
    default {
        Write-Host "Test Execution Verification"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  count-expected <test-specs-file>     Count TS-XXX entries in test specs"
        Write-Host "  parse-output <output-string>         Parse test runner output for counts"
        Write-Host "  verify <specs-file> <output>         Compare expected vs actual"
        Write-Host ""
        Write-Host "Supported test runners: Jest, Vitest, Pytest, Go test, Playwright, Mocha"
    }
}
