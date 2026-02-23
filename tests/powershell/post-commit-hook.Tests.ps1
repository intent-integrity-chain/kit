# Tests for post-commit-hook.ps1

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:PostHookScript = Join-Path $Global:ScriptsDir "post-commit-hook.ps1"
    $script:TestifyScript = Join-Path $Global:ScriptsDir "testify-tdd.ps1"
    $script:BashScriptsDir = Join-Path (Split-Path $Global:ScriptsDir -Parent) "bash"
    $script:BashPostHook = Join-Path $script:BashScriptsDir "post-commit-hook.sh"
    $script:BashPreHook = Join-Path $script:BashScriptsDir "pre-commit-hook.sh"

    function script:New-PostHookTestDirectory {
        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "iikit-posthook-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null

        Push-Location $testDir
        git init . 2>&1 | Out-Null
        git config user.email "test@test.com"
        git config user.name "Test"

        # Copy IIKit scripts
        $scriptsTarget = Join-Path $testDir ".claude/skills/iikit-core/scripts/powershell"
        New-Item -ItemType Directory -Path $scriptsTarget -Force | Out-Null
        Copy-Item (Join-Path $Global:ScriptsDir "testify-tdd.ps1") $scriptsTarget
        Copy-Item $script:PostHookScript $scriptsTarget

        $bashTarget = Join-Path $testDir ".claude/skills/iikit-core/scripts/bash"
        New-Item -ItemType Directory -Path $bashTarget -Force | Out-Null
        Copy-Item (Join-Path $script:BashScriptsDir "common.sh") $bashTarget
        Copy-Item (Join-Path $script:BashScriptsDir "testify-tdd.sh") $bashTarget
        Copy-Item $script:BashPostHook $bashTarget
        chmod +x (Join-Path $bashTarget "common.sh")
        chmod +x (Join-Path $bashTarget "testify-tdd.sh")
        chmod +x (Join-Path $bashTarget "post-commit-hook.sh")

        # Install bash post-commit hook
        $hooksDir = Join-Path $testDir ".git/hooks"
        New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
        Copy-Item $script:BashPostHook (Join-Path $hooksDir "post-commit")
        chmod +x (Join-Path $hooksDir "post-commit")

        New-Item -ItemType Directory -Path (Join-Path $testDir ".specify") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $testDir "specs") -Force | Out-Null

        git add -A 2>&1 | Out-Null
        git commit -m "initial setup" 2>&1 | Out-Null
        Pop-Location

        return $testDir
    }

    function script:Remove-PostHookTestDirectory {
        param([string]$TestDir)
        if ($TestDir -and (Test-Path $TestDir)) {
            Remove-Item -Path $TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Post-Commit Hook - Basic Behavior" {
    BeforeEach {
        $script:TestDir = New-PostHookTestDirectory
    }

    AfterEach {
        Remove-PostHookTestDirectory -TestDir $script:TestDir
    }

    It "no note when no test-specs.md committed" {
        Push-Location $script:TestDir
        "hello" | Out-File "README.md"
        git add README.md 2>&1 | Out-Null
        git commit -m "add readme" 2>&1 | Out-Null

        $note = git notes --ref=refs/notes/testify show HEAD 2>$null
        $LASTEXITCODE | Should -Not -Be 0
        Pop-Location
    }

    It "creates git note when test-specs.md committed" {
        Push-Location $script:TestDir

        $specsDir = Join-Path $script:TestDir "specs/001-feature/tests"
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        @"
**Given**: a user is logged in
**When**: they click logout
**Then**: they are redirected
"@ | Out-File (Join-Path $specsDir "test-specs.md") -Encoding utf8

        git add (Join-Path $specsDir "test-specs.md") 2>&1 | Out-Null
        git commit -m "add test specs" 2>&1 | Out-Null

        $note = (git notes --ref=refs/notes/testify show HEAD 2>$null) -join "`n"
        $LASTEXITCODE | Should -Be 0
        $note | Should -Match "testify-hash:"
        Pop-Location
    }

    It "no note for test-specs.md without assertions" {
        Push-Location $script:TestDir

        $specsDir = Join-Path $script:TestDir "specs/001-feature/tests"
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        "# Empty test specs" | Out-File (Join-Path $specsDir "test-specs.md")

        git add (Join-Path $specsDir "test-specs.md") 2>&1 | Out-Null
        git commit -m "empty test specs" 2>&1 | Out-Null

        $note = git notes --ref=refs/notes/testify show HEAD 2>$null
        $LASTEXITCODE | Should -Not -Be 0
        Pop-Location
    }
}

Describe "Post-Commit Hook - Scripts Not Found" {
    It "commit succeeds when scripts not found" {
        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "iikit-noscript-post-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null

        Push-Location $testDir
        git init . 2>&1 | Out-Null
        git config user.email "test@test.com"
        git config user.name "Test"

        $hooksDir = Join-Path $testDir ".git/hooks"
        New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
        Copy-Item $script:BashPostHook (Join-Path $hooksDir "post-commit")
        chmod +x (Join-Path $hooksDir "post-commit")

        "init" | Out-File "init.txt"
        git add -A 2>&1 | Out-Null
        git commit -m "init" 2>&1 | Out-Null

        $specsDir = Join-Path $testDir "specs/001/tests"
        New-Item -ItemType Directory -Path $specsDir -Force | Out-Null
        "**Given**: test" | Out-File (Join-Path $specsDir "test-specs.md")
        git add (Join-Path $specsDir "test-specs.md") 2>&1 | Out-Null

        { git commit -m "add specs" 2>&1 | Out-Null } | Should -Not -Throw

        Pop-Location
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
