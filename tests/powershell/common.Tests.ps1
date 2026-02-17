# Tests for common.ps1 functions

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    . "$Global:ScriptsDir/common.ps1"
}

Describe "Get-RepoRoot" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns git root in git repo" {
        # TestDir already has git initialized by New-TestDirectory
        $result = Get-RepoRoot
        # Normalize paths to handle macOS /var -> /private/var symlink
        # Strip /private prefix if present for comparison
        $normalizedResult = $result -replace '^/private', ''
        $normalizedExpected = $script:TestDir -replace '^/private', ''
        $normalizedResult | Should -Be $normalizedExpected
    }

    It "returns a valid directory in non-git repo" {
        $result = Get-RepoRoot
        Test-Path $result | Should -Be $true
    }
}

Describe "Get-CurrentBranch" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        $env:SPECIFY_FEATURE = $null
    }

    AfterEach {
        Pop-Location
        $env:SPECIFY_FEATURE = $null
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns SPECIFY_FEATURE if set" {
        $env:SPECIFY_FEATURE = "test-feature"
        $result = Get-CurrentBranch
        $result | Should -Be "test-feature"
    }

    It "returns git branch in git repo" {
        git init . 2>&1 | Out-Null
        git config user.email "test@test.com"
        git config user.name "Test"
        "test" | Out-File test.txt
        git add test.txt
        git commit -m "initial" 2>&1 | Out-Null

        $result = Get-CurrentBranch
        $result | Should -BeIn @("main", "master")
    }

    It "returns main as fallback in non-git repo" {
        # Remove git to simulate non-git repo
        Remove-Item ".git" -Recurse -Force -ErrorAction SilentlyContinue

        # Create feature dirs (but they won't be found because Get-RepoRoot
        # falls back to script location, not current directory)
        New-Item -ItemType Directory -Path "specs/001-first-feature" -Force | Out-Null
        New-Item -ItemType Directory -Path "specs/002-second-feature" -Force | Out-Null

        $result = Get-CurrentBranch
        # Without git, Get-RepoRoot falls back to script location which doesn't
        # have these test specs, so it returns "main" as final fallback
        $result | Should -Be "main"
    }
}

Describe "Test-FeatureBranch" {
    It "accepts NNN- pattern" {
        $result = Test-FeatureBranch -Branch "001-test-feature" -HasGit $true
        $result | Should -Be $true
    }

    It "accepts SPECIFY_FEATURE override" {
        $env:SPECIFY_FEATURE = "manual-override"
        $result = Test-FeatureBranch -Branch "main" -HasGit $true
        $result | Should -Be $true
        $env:SPECIFY_FEATURE = $null
    }
}

Describe "Find-FeatureDirByPrefix" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "finds matching prefix" {
        New-Item -ItemType Directory -Path "specs/004-original-feature" -Force | Out-Null

        $result = Find-FeatureDirByPrefix -RepoRoot $script:TestDir -BranchName "004-fix-typo"
        $result | Should -Match "004-original-feature"
    }

    It "returns exact path for non-prefixed branch" {
        $result = Find-FeatureDirByPrefix -RepoRoot $script:TestDir -BranchName "main"
        $result | Should -Be (Join-Path $script:TestDir "specs/main")
    }

    It "returns branch path when no match" {
        $result = Find-FeatureDirByPrefix -RepoRoot $script:TestDir -BranchName "999-nonexistent"
        $result | Should -Be (Join-Path $script:TestDir "specs/999-nonexistent")
    }
}

Describe "Test-Constitution" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "passes with valid constitution" {
        $result = Test-Constitution -RepoRoot $script:TestDir
        $result | Should -Be $true
    }

    It "fails when constitution missing" {
        Remove-Item "CONSTITUTION.md"
        $result = Test-Constitution -RepoRoot $script:TestDir -ErrorAction SilentlyContinue
        $result | Should -Be $false
    }
}

Describe "Test-Spec" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "passes with valid spec" {
        $featureDir = New-MockFeature -TestDir $script:TestDir
        $result = Test-Spec -SpecFile (Join-Path $featureDir "spec.md")
        $result | Should -Be $true
    }

    It "fails when spec missing" {
        $result = Test-Spec -SpecFile "nonexistent/spec.md" -ErrorAction SilentlyContinue
        $result | Should -Be $false
    }

    It "fails when missing required sections" {
        $featureDir = New-MockFeature -TestDir $script:TestDir
        "# Empty Spec" | Out-File (Join-Path $featureDir "spec.md")
        $result = Test-Spec -SpecFile (Join-Path $featureDir "spec.md") -ErrorAction SilentlyContinue
        $result | Should -Be $false
    }
}

Describe "Test-Tasks" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "passes with valid tasks" {
        $featureDir = New-CompleteMockFeature -TestDir $script:TestDir
        $result = Test-Tasks -TasksFile (Join-Path $featureDir "tasks.md")
        $result | Should -Be $true
    }

    It "fails when tasks missing" {
        $result = Test-Tasks -TasksFile "nonexistent/tasks.md" -ErrorAction SilentlyContinue
        $result | Should -Be $false
    }
}

Describe "Get-SpecQualityScore" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns high score for good spec" {
        $featureDir = New-MockFeature -TestDir $script:TestDir
        $result = Get-SpecQualityScore -SpecFile (Join-Path $featureDir "spec.md")
        $result | Should -BeGreaterOrEqual 6
    }

    It "returns 0 for missing spec" {
        $result = Get-SpecQualityScore -SpecFile "nonexistent.md"
        $result | Should -Be 0
    }

    It "returns low score for incomplete spec" {
        New-Item -ItemType Directory -Path "specs/incomplete" -Force | Out-Null
        Copy-Item (Join-Path $Global:FixturesDir "spec-incomplete.md") "specs/incomplete/spec.md"
        $result = Get-SpecQualityScore -SpecFile "specs/incomplete/spec.md"
        $result | Should -BeLessThan 6
    }
}

Describe "Write-ActiveFeature / Read-ActiveFeature" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "writes and reads active feature" {
        New-Item -ItemType Directory -Path "specs/001-test-feature" -Force | Out-Null
        Write-ActiveFeature -Feature "001-test-feature"
        $result = Read-ActiveFeature
        $result | Should -Be "001-test-feature"
    }

    It "returns null for missing active-feature file" {
        $result = Read-ActiveFeature
        $result | Should -BeNullOrEmpty
    }

    It "returns null for invalid feature directory" {
        New-Item -ItemType Directory -Path ".specify" -Force | Out-Null
        "999-nonexistent" | Out-File ".specify/active-feature" -NoNewline
        $result = Read-ActiveFeature
        $result | Should -BeNullOrEmpty
    }
}

Describe "Get-FeatureStage" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns specified for spec-only feature" {
        New-Item -ItemType Directory -Path "specs/001-test" -Force | Out-Null
        "# Spec" | Out-File "specs/001-test/spec.md"
        $result = Get-FeatureStage -RepoRoot $script:TestDir -Feature "001-test"
        $result | Should -Be "specified"
    }

    It "returns planned for feature with plan" {
        New-Item -ItemType Directory -Path "specs/001-test" -Force | Out-Null
        "# Spec" | Out-File "specs/001-test/spec.md"
        "# Plan" | Out-File "specs/001-test/plan.md"
        $result = Get-FeatureStage -RepoRoot $script:TestDir -Feature "001-test"
        $result | Should -Be "planned"
    }

    It "returns tasks-ready for untouched tasks" {
        New-Item -ItemType Directory -Path "specs/001-test" -Force | Out-Null
        @("- [ ] T001 Do something", "- [ ] T002 Do another") | Out-File "specs/001-test/tasks.md"
        $result = Get-FeatureStage -RepoRoot $script:TestDir -Feature "001-test"
        $result | Should -Be "tasks-ready"
    }

    It "returns implementing percentage" {
        New-Item -ItemType Directory -Path "specs/001-test" -Force | Out-Null
        @("- [x] T001 Done", "- [ ] T002 Not done") | Out-File "specs/001-test/tasks.md"
        $result = Get-FeatureStage -RepoRoot $script:TestDir -Feature "001-test"
        $result | Should -Be "implementing-50%"
    }

    It "returns complete for all done" {
        New-Item -ItemType Directory -Path "specs/001-test" -Force | Out-Null
        @("- [x] T001 Done", "- [x] T002 Also done") | Out-File "specs/001-test/tasks.md"
        $result = Get-FeatureStage -RepoRoot $script:TestDir -Feature "001-test"
        $result | Should -Be "complete"
    }

    It "returns unknown for nonexistent feature" {
        $result = Get-FeatureStage -RepoRoot $script:TestDir -Feature "999-nope"
        $result | Should -Be "unknown"
    }
}

Describe "Test-FeatureBranch exit code 2" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        $env:SPECIFY_FEATURE = $null
    }

    AfterEach {
        Pop-Location
        $env:SPECIFY_FEATURE = $null
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns NEEDS_SELECTION for multiple features" {
        New-Item -ItemType Directory -Path "specs/001-first" -Force | Out-Null
        New-Item -ItemType Directory -Path "specs/002-second" -Force | Out-Null
        $result = Test-FeatureBranch -Branch "main" -HasGit $true
        $result | Should -Contain "NEEDS_SELECTION"
    }

    It "writes sticky on NNN- branch match" {
        $result = Test-FeatureBranch -Branch "001-test-feature" -HasGit $true
        $result | Should -Be "OK"
        Test-Path ".specify/active-feature" | Should -Be $true
    }

    It "writes sticky on single feature auto-select" {
        New-Item -ItemType Directory -Path "specs/001-only-feature" -Force | Out-Null
        $result = Test-FeatureBranch -Branch "main" -HasGit $true
        $result | Should -Be "OK"
    }
}
