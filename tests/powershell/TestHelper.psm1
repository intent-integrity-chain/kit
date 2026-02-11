# Test helper module for Pester tests

$script:TestsDir = Split-Path -Parent $PSScriptRoot
$script:ScriptsDir = Join-Path (Split-Path -Parent $TestsDir) "scripts/powershell"
$script:FixturesDir = Join-Path $TestsDir "fixtures"

# Export paths
$Global:TestsDir = $script:TestsDir
$Global:ScriptsDir = $script:ScriptsDir
$Global:FixturesDir = $script:FixturesDir

function New-TestDirectory {
    <#
    .SYNOPSIS
    Creates a temporary test directory with basic spec-kit structure
    #>
    $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "speckit-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    # Initialize git so this directory is its own repo root
    # This prevents git from walking up to find the parent repo
    Push-Location $testDir
    git init . 2>&1 | Out-Null
    git config user.email "test@test.com"
    git config user.name "Test"
    Pop-Location

    # Create basic structure
    New-Item -ItemType Directory -Path (Join-Path $testDir ".specify/memory") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $testDir "specs") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $testDir ".claude/skills/iikit-core/templates") -Force | Out-Null

    # Copy constitution fixture
    Copy-Item (Join-Path $script:FixturesDir "constitution.md") (Join-Path $testDir ".specify/memory/constitution.md")
    # Also copy to root level (where validate_constitution looks for it)
    Copy-Item (Join-Path $script:FixturesDir "constitution.md") (Join-Path $testDir "CONSTITUTION.md")

    # Initial commit so git commands work properly
    Push-Location $testDir
    git add -A 2>&1 | Out-Null
    git commit -m "test setup" 2>&1 | Out-Null
    Pop-Location

    return $testDir
}

function Remove-TestDirectory {
    param([string]$TestDir)

    if ($TestDir -and (Test-Path $TestDir)) {
        Remove-Item -Path $TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function New-MockFeature {
    <#
    .SYNOPSIS
    Creates a mock feature directory with spec and plan
    #>
    param(
        [string]$TestDir,
        [string]$FeatureName = "001-test-feature"
    )

    $featureDir = Join-Path $TestDir "specs/$FeatureName"
    New-Item -ItemType Directory -Path $featureDir -Force | Out-Null

    Copy-Item (Join-Path $script:FixturesDir "spec.md") (Join-Path $featureDir "spec.md")
    Copy-Item (Join-Path $script:FixturesDir "plan.md") (Join-Path $featureDir "plan.md")

    return $featureDir
}

function New-CompleteMockFeature {
    <#
    .SYNOPSIS
    Creates a complete mock feature with tasks and test specs
    #>
    param(
        [string]$TestDir,
        [string]$FeatureName = "001-test-feature"
    )

    $featureDir = New-MockFeature -TestDir $TestDir -FeatureName $FeatureName

    Copy-Item (Join-Path $script:FixturesDir "tasks.md") (Join-Path $featureDir "tasks.md")

    $testsDir = Join-Path $featureDir "tests"
    New-Item -ItemType Directory -Path $testsDir -Force | Out-Null
    Copy-Item (Join-Path $script:FixturesDir "test-specs.md") (Join-Path $testsDir "test-specs.md")

    return $featureDir
}

Export-ModuleMember -Function @(
    'New-TestDirectory',
    'Remove-TestDirectory',
    'New-MockFeature',
    'New-CompleteMockFeature'
) -Variable @(
    'TestsDir',
    'ScriptsDir',
    'FixturesDir'
)
