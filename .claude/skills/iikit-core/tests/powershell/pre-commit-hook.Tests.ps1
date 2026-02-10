# Tests for pre-commit-hook.ps1

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:HookScript = Join-Path (Split-Path $Global:ScriptsDir -Parent) "bash/pre-commit-hook.sh"
    $script:PsHookScript = Join-Path $Global:ScriptsDir "pre-commit-hook.ps1"
    $script:TestifyScript = Join-Path $Global:ScriptsDir "testify-tdd.ps1"
    $script:BashScriptsDir = Join-Path (Split-Path $Global:ScriptsDir -Parent) "bash"
}

function New-HookTestDirectory {
    <#
    .SYNOPSIS
    Creates a temporary test directory with git init and iikit scripts for hook testing
    #>
    $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "iikit-hook-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    # Initialize git
    Push-Location $testDir
    git init . 2>&1 | Out-Null
    git config user.email "test@test.com"
    git config user.name "Test"

    # Copy IIKit scripts into the test directory
    $scriptsTarget = Join-Path $testDir ".claude/skills/iikit-core/scripts/powershell"
    New-Item -ItemType Directory -Path $scriptsTarget -Force | Out-Null
    Copy-Item (Join-Path $Global:ScriptsDir "testify-tdd.ps1") $scriptsTarget
    Copy-Item (Join-Path $Global:ScriptsDir "pre-commit-hook.ps1") $scriptsTarget

    # Also copy bash scripts (for bash-based functions)
    $bashTarget = Join-Path $testDir ".claude/skills/iikit-core/scripts/bash"
    New-Item -ItemType Directory -Path $bashTarget -Force | Out-Null
    Copy-Item (Join-Path $script:BashScriptsDir "common.sh") $bashTarget
    Copy-Item (Join-Path $script:BashScriptsDir "testify-tdd.sh") $bashTarget
    Copy-Item $script:HookScript $bashTarget

    # Install bash hook (git hooks always use bash)
    $hooksDir = Join-Path $testDir ".git/hooks"
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
    Copy-Item $script:HookScript (Join-Path $hooksDir "pre-commit")

    # Create basic structure
    New-Item -ItemType Directory -Path (Join-Path $testDir ".specify") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $testDir "specs") -Force | Out-Null

    # Initial commit
    git add -A 2>&1 | Out-Null
    git commit -m "initial setup" 2>&1 | Out-Null
    Pop-Location

    return $testDir
}

function Remove-HookTestDirectory {
    param([string]$TestDir)
    if ($TestDir -and (Test-Path $TestDir)) {
        Remove-Item -Path $TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Pre-Commit Hook - Fast Path" {
    BeforeEach {
        $script:TestDir = New-HookTestDirectory
    }

    AfterEach {
        Remove-HookTestDirectory -TestDir $script:TestDir
    }

    It "exits 0 when no test-specs.md staged" {
        Push-Location $script:TestDir
        "hello" | Out-File "README.md"
        git add README.md 2>&1 | Out-Null

        $result = & $script:PsHookScript 2>&1
        $LASTEXITCODE | Should -Be 0
        Pop-Location
    }
}

Describe "Pre-Commit Hook - Valid Hash" {
    BeforeEach {
        $script:TestDir = New-HookTestDirectory
    }

    AfterEach {
        Remove-HookTestDirectory -TestDir $script:TestDir
    }

    It "exits 0 when test-specs.md staged with valid hash" {
        Push-Location $script:TestDir

        # Create test-specs
        $specsDir = Join-Path $script:TestDir "specs/001-feature/tests"
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        $testSpecsPath = Join-Path $specsDir "test-specs.md"
        @"
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected to login page
"@ | Out-File $testSpecsPath -Encoding utf8

        # Store hash
        $contextFile = Join-Path $script:TestDir ".specify/context.json"
        & $script:TestifyScript store-hash $testSpecsPath $contextFile | Out-Null

        # Commit
        git add -A 2>&1 | Out-Null
        git commit -m "add test specs" 2>&1 | Out-Null

        # Re-stage unchanged
        git add $testSpecsPath 2>&1 | Out-Null

        $result = & $script:PsHookScript 2>&1
        $LASTEXITCODE | Should -Be 0
        Pop-Location
    }
}

Describe "Pre-Commit Hook - Tampered Assertions" {
    BeforeEach {
        $script:TestDir = New-HookTestDirectory
    }

    AfterEach {
        Remove-HookTestDirectory -TestDir $script:TestDir
    }

    It "exits 1 when assertions tampered" {
        Push-Location $script:TestDir

        # Create test-specs
        $specsDir = Join-Path $script:TestDir "specs/001-feature/tests"
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        $testSpecsPath = Join-Path $specsDir "test-specs.md"
        @"
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected to login page
"@ | Out-File $testSpecsPath -Encoding utf8

        # Store hash
        $contextFile = Join-Path $script:TestDir ".specify/context.json"
        & $script:TestifyScript store-hash $testSpecsPath $contextFile | Out-Null

        # Commit original
        git add -A 2>&1 | Out-Null
        git commit -m "original" 2>&1 | Out-Null

        # Tamper
        @"
**Given**: a user is logged in
**When**: they click logout
**Then**: they see a success message instead
"@ | Out-File $testSpecsPath -Encoding utf8

        git add $testSpecsPath 2>&1 | Out-Null

        & $script:PsHookScript 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 1
        Pop-Location
    }
}

Describe "Pre-Commit Hook - Missing Hash" {
    BeforeEach {
        $script:TestDir = New-HookTestDirectory
    }

    AfterEach {
        Remove-HookTestDirectory -TestDir $script:TestDir
    }

    It "exits 0 when no context.json exists" {
        Push-Location $script:TestDir

        $specsDir = Join-Path $script:TestDir "specs/001-feature/tests"
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        @"
**Given**: a test
**Then**: a result
"@ | Out-File (Join-Path $specsDir "test-specs.md") -Encoding utf8

        Remove-Item (Join-Path $script:TestDir ".specify/context.json") -ErrorAction SilentlyContinue

        git add (Join-Path $specsDir "test-specs.md") 2>&1 | Out-Null

        $result = & $script:PsHookScript 2>&1
        $LASTEXITCODE | Should -Be 0
        Pop-Location
    }
}

Describe "Pre-Commit Hook - Scripts Not Found" {
    It "exits 0 with warning when scripts directory not found" {
        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "iikit-noscript-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null

        Push-Location $testDir
        git init . 2>&1 | Out-Null
        git config user.email "test@test.com"
        git config user.name "Test"

        "init" | Out-File "init.txt"
        git add -A 2>&1 | Out-Null
        git commit -m "init" 2>&1 | Out-Null

        $specsDir = Join-Path $testDir "specs/001/tests"
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        "**Given**: test" | Out-File (Join-Path $specsDir "test-specs.md")
        git add (Join-Path $specsDir "test-specs.md") 2>&1 | Out-Null

        $result = & $script:PsHookScript 2>&1
        $LASTEXITCODE | Should -Be 0

        Pop-Location
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
