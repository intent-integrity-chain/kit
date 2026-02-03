#!/usr/bin/env pwsh
<#
.SYNOPSIS
Run all PowerShell tests using Pester

.DESCRIPTION
Runs the Pester test suite for intent-integrity-kit PowerShell scripts.

Prerequisites:
  - Pester 5.x: Install-Module Pester -Force -SkipPublisherCheck

.PARAMETER TestFile
Optional. Run specific test file (without .Tests.ps1 extension)

.PARAMETER Verbose
Show verbose output

.EXAMPLE
./run-tests.ps1              # Run all tests

.EXAMPLE
./run-tests.ps1 common       # Run common.Tests.ps1

.EXAMPLE
./run-tests.ps1 -Verbose     # Run all with verbose output
#>

param(
    [Parameter(Position = 0)]
    [string]$TestFile,

    [switch]$ShowHelp
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PowerShellTestsDir = Join-Path $ScriptDir "powershell"

if ($ShowHelp) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# Check for Pester
$pester = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -ge 5 }
if (-not $pester) {
    Write-Host "ERROR: Pester 5.x is not installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install with:"
    Write-Host "  Install-Module Pester -Force -SkipPublisherCheck"
    exit 1
}

Import-Module Pester -MinimumVersion 5.0

Write-Host "======================================"
Write-Host "  Running PowerShell Tests (Pester)"
Write-Host "======================================"
Write-Host ""

# Configure Pester
$config = New-PesterConfiguration
$config.Run.Path = $PowerShellTestsDir
$config.Output.Verbosity = "Detailed"
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = Join-Path $ScriptDir "test-results.xml"

if ($TestFile) {
    $testPath = Join-Path $PowerShellTestsDir "${TestFile}.Tests.ps1"
    if (-not (Test-Path $testPath)) {
        Write-Host "ERROR: Test file not found: $testPath" -ForegroundColor Red
        exit 1
    }
    $config.Run.Path = $testPath
}

# Run tests
$result = Invoke-Pester -Configuration $config

Write-Host ""

if ($result.FailedCount -gt 0) {
    Write-Host "======================================"
    Write-Host "  $($result.FailedCount) test(s) failed!"
    Write-Host "======================================"
    exit 1
} else {
    Write-Host "======================================"
    Write-Host "  All PowerShell tests passed!"
    Write-Host "======================================"
}
