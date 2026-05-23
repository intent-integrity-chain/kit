# Tests for uninit.ps1 — removes iikit scaffolding before `tessl uninstall`.

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:UninitScript = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "tiles/intent-integrity-kit/skills/iikit-core/scripts/powershell/uninit.ps1"
    $script:HooksSubdir = ".git/hooks"

    function Install-MarkerHook {
        param([string]$TestDir, [string]$Hook, [string]$Marker)
        $hookPath = Join-Path $TestDir ".git/hooks/$Hook"
        @(
            "#!/usr/bin/env bash",
            "# $Marker",
            "echo iikit-$Hook"
        ) | Set-Content $hookPath
    }
}

Describe "uninit: tile-managed scaffolding" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        # The TestHelper installs CONSTITUTION.md and a memory copy; strip them so
        # individual tests start without preconditions they did not opt into.
        Remove-Item "CONSTITUTION.md" -Force -ErrorAction SilentlyContinue
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "removes marker-owned pre-commit hook" {
        Install-MarkerHook -TestDir $script:TestDir -Hook "pre-commit" -Marker "IIKIT-PRE-COMMIT"

        & $script:UninitScript -Json | Out-Null

        (Test-Path (Join-Path $script:TestDir "$script:HooksSubdir/pre-commit")) | Should -BeFalse
    }

    It "removes marker-owned post-commit hook" {
        Install-MarkerHook -TestDir $script:TestDir -Hook "post-commit" -Marker "IIKIT-POST-COMMIT"

        & $script:UninitScript -Json | Out-Null

        (Test-Path (Join-Path $script:TestDir "$script:HooksSubdir/post-commit")) | Should -BeFalse
    }

    It "keeps non-iikit hook untouched" {
        @(
            "#!/usr/bin/env bash",
            "echo user hook"
        ) | Set-Content (Join-Path $script:TestDir "$script:HooksSubdir/pre-commit")

        & $script:UninitScript -Json | Out-Null

        $hook = Get-Content (Join-Path $script:TestDir "$script:HooksSubdir/pre-commit") -Raw
        $hook | Should -Match "echo user hook"
    }

    It "strips iikit chain-call from existing user hook" {
        @(
            "#!/usr/bin/env bash",
            "echo user post-commit",
            "",
            "# IIKit assertion integrity check",
            '"$(dirname "$0")/iikit-post-commit"'
        ) | Set-Content (Join-Path $script:TestDir "$script:HooksSubdir/post-commit")
        Install-MarkerHook -TestDir $script:TestDir -Hook "iikit-post-commit" -Marker "IIKIT-POST-COMMIT"

        & $script:UninitScript -Json | Out-Null

        $hook = Get-Content (Join-Path $script:TestDir "$script:HooksSubdir/post-commit") -Raw
        $hook | Should -Match "echo user post-commit"
        $hook | Should -Not -Match "iikit-post-commit"
        $hook | Should -Not -Match "IIKit assertion integrity check"
    }

    It "removes .specify directory" {
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir ".specify") -Force | Out-Null
        "{}" | Set-Content (Join-Path $script:TestDir ".specify/context.json")

        & $script:UninitScript -Json | Out-Null

        (Test-Path (Join-Path $script:TestDir ".specify")) | Should -BeFalse
    }

    It "removes TECH.md only when it references an iikit phase" {
        "Pre-plan notes referencing /iikit-02-plan" | Set-Content (Join-Path $script:TestDir "TECH.md")

        & $script:UninitScript -Json | Out-Null

        (Test-Path (Join-Path $script:TestDir "TECH.md")) | Should -BeFalse
    }

    It "preserves TECH.md when it does not reference an iikit phase" {
        "Generic technical notes" | Set-Content (Join-Path $script:TestDir "TECH.md")

        & $script:UninitScript -Json | Out-Null

        (Test-Path (Join-Path $script:TestDir "TECH.md")) | Should -BeTrue
    }
}

Describe "uninit: user-authored content" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        Remove-Item "CONSTITUTION.md" -Force -ErrorAction SilentlyContinue
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "lists user content but does not delete by default" {
        "# Constitution" | Set-Content (Join-Path $script:TestDir "CONSTITUTION.md")
        "# Premise" | Set-Content (Join-Path $script:TestDir "PREMISE.md")
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir "specs/001-foo") -Force | Out-Null

        $result = & $script:UninitScript -Json

        (Test-Path (Join-Path $script:TestDir "CONSTITUTION.md")) | Should -BeTrue
        (Test-Path (Join-Path $script:TestDir "PREMISE.md")) | Should -BeTrue
        (Test-Path (Join-Path $script:TestDir "specs/001-foo")) | Should -BeTrue
        $result | Should -Match "CONSTITUTION.md"
        $result | Should -Match "PREMISE.md"
        $result | Should -Match "specs"
    }

    It "-RemoveUserContent deletes user-authored files" {
        "# Constitution" | Set-Content (Join-Path $script:TestDir "CONSTITUTION.md")
        "# Premise" | Set-Content (Join-Path $script:TestDir "PREMISE.md")
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir "specs/001-foo") -Force | Out-Null

        & $script:UninitScript -Json -RemoveUserContent | Out-Null

        (Test-Path (Join-Path $script:TestDir "CONSTITUTION.md")) | Should -BeFalse
        (Test-Path (Join-Path $script:TestDir "PREMISE.md")) | Should -BeFalse
        (Test-Path (Join-Path $script:TestDir "specs")) | Should -BeFalse
    }
}

Describe "uninit: -DryRun" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        Remove-Item "CONSTITUTION.md" -Force -ErrorAction SilentlyContinue
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "reports without modifying anything" {
        Install-MarkerHook -TestDir $script:TestDir -Hook "pre-commit" -Marker "IIKIT-PRE-COMMIT"
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir ".specify") -Force | Out-Null

        $result = & $script:UninitScript -Json -DryRun

        (Test-Path (Join-Path $script:TestDir "$script:HooksSubdir/pre-commit")) | Should -BeTrue
        (Test-Path (Join-Path $script:TestDir ".specify")) | Should -BeTrue
        $result | Should -Match '"dry_run":\s*true'
        $result | Should -Match "\.specify"
    }
}

Describe "uninit: JSON shape" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        Remove-Item "CONSTITUTION.md" -Force -ErrorAction SilentlyContinue
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "includes next_step pointing at tessl uninstall" {
        $result = & $script:UninitScript -Json

        $result | Should -Match "tessl uninstall tessl-labs/intent-integrity-kit"
    }
}

Describe "uninit: pre-commit.d handling" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        Remove-Item "CONSTITUTION.md" -Force -ErrorAction SilentlyContinue
        $script:PreCommitD = Join-Path $script:TestDir "$script:HooksSubdir/pre-commit.d"
        New-Item -ItemType Directory -Path $script:PreCommitD -Force | Out-Null
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "removes IIKit-managed README and empty pre-commit.d" {
        "# IIKit pre-commit extension point — IIKIT-PRE-COMMIT-D" | Set-Content (Join-Path $script:PreCommitD "README")

        $result = & $script:UninitScript -Json | Out-String

        (Test-Path $script:PreCommitD) | Should -BeFalse
        $result | Should -Match "pre-commit.d"
    }

    It "preserves user scripts and reports them" {
        "# IIKit pre-commit extension point — IIKIT-PRE-COMMIT-D" | Set-Content (Join-Path $script:PreCommitD "README")
        "#!/bin/sh" | Set-Content (Join-Path $script:PreCommitD "prettier")

        $result = & $script:UninitScript -Json | Out-String

        (Test-Path (Join-Path $script:PreCommitD "README")) | Should -BeFalse
        (Test-Path (Join-Path $script:PreCommitD "prettier")) | Should -BeTrue
        (Test-Path $script:PreCommitD) | Should -BeTrue
        $result | Should -Match "prettier"
    }

    It "leaves a non-iikit README untouched" {
        "# Team docs — not iikit-managed" | Set-Content (Join-Path $script:PreCommitD "README")

        & $script:UninitScript -Json | Out-Null

        (Test-Path (Join-Path $script:PreCommitD "README")) | Should -BeTrue
    }

    It "-DryRun does not double-count the managed README" {
        # Clear default user-content setup so user_content reflects only this test's intent
        Remove-Item (Join-Path $script:TestDir ".specify") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $script:TestDir "specs") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $script:TestDir "CONSTITUTION.md") -Force -ErrorAction SilentlyContinue

        "# IIKit pre-commit extension point — IIKIT-PRE-COMMIT-D" | Set-Content (Join-Path $script:PreCommitD "README")

        $result = & $script:UninitScript -Json -DryRun | Out-String

        # README must appear in removed (as planned) but NOT in user_content
        $result | Should -Match "pre-commit.d/README"
        $result | Should -Match '"user_content":\s*\[\s*\]'
        # Disk state unchanged in dry-run
        (Test-Path (Join-Path $script:PreCommitD "README")) | Should -BeTrue
        (Test-Path $script:PreCommitD) | Should -BeTrue
    }
}
