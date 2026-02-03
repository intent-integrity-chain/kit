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
        git init . 2>&1 | Out-Null
        $result = Get-RepoRoot
        $result | Should -Be $script:TestDir
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

    It "returns latest feature dir in non-git repo" {
        New-Item -ItemType Directory -Path "specs/001-first-feature" -Force | Out-Null
        New-Item -ItemType Directory -Path "specs/002-second-feature" -Force | Out-Null

        $result = Get-CurrentBranch
        $result | Should -Be "002-second-feature"
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
        Remove-Item ".specify/memory/constitution.md"
        $result = Test-Constitution -RepoRoot $script:TestDir 2>$null
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
        $result = Test-Spec -SpecFile "nonexistent/spec.md" 2>$null
        $result | Should -Be $false
    }

    It "fails when missing required sections" {
        $featureDir = New-MockFeature -TestDir $script:TestDir
        "# Empty Spec" | Out-File (Join-Path $featureDir "spec.md")
        $result = Test-Spec -SpecFile (Join-Path $featureDir "spec.md") 2>$null
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
        $result = Test-Tasks -TasksFile "nonexistent/tasks.md" 2>$null
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
