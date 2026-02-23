# Tests for setup-plan.ps1

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    . "$Global:ScriptsDir/common.ps1"
    $script:SetupPlanScript = Join-Path $Global:ScriptsDir "setup-plan.ps1"
}

Describe "setup-plan" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir

        # Initialize git
        git init . 2>&1 | Out-Null
        git config user.email "test@test.com"
        git config user.name "Test"
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    Context "Prerequisites" {
        It "fails without constitution" {
            Remove-Item "CONSTITUTION.md" -ErrorAction SilentlyContinue
            Remove-Item ".specify/memory/constitution.md" -ErrorAction SilentlyContinue
            & $script:SetupPlanScript *>&1 | Out-Null
            $LASTEXITCODE | Should -Not -Be 0
        }

        It "fails without spec.md" {
            & $script:SetupPlanScript *>&1 | Out-Null
            $LASTEXITCODE | Should -Not -Be 0
        }

        It "succeeds with valid prerequisites" {
            $featureDir = New-MockFeature -TestDir $script:TestDir
            git checkout -b "001-test-feature" 2>&1 | Out-Null

            & $script:SetupPlanScript *>&1 | Out-Null
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Plan creation" {
        It "creates plan.md from template" {
            $featureDir = New-MockFeature -TestDir $script:TestDir
            Remove-Item (Join-Path $featureDir "plan.md") -ErrorAction SilentlyContinue
            git checkout -b "001-test-feature" 2>&1 | Out-Null

            & $script:SetupPlanScript

            Test-Path (Join-Path $featureDir "plan.md") | Should -Be $true
        }

        It "reports spec quality" {
            $featureDir = New-MockFeature -TestDir $script:TestDir
            git checkout -b "001-test-feature" 2>&1 | Out-Null

            $output = & $script:SetupPlanScript 2>&1 | Out-String
            $output | Should -Match "quality"
        }
    }

    Context "JSON output" {
        It "outputs valid JSON with -Json" {
            $featureDir = New-MockFeature -TestDir $script:TestDir
            git checkout -b "001-test-feature" 2>&1 | Out-Null

            $result = & $script:SetupPlanScript -Json | Out-String

            $result | Should -Match '"FEATURE_SPEC"'
            $result | Should -Match '"IMPL_PLAN"'
            $result | Should -Match '"FEATURE_DIR"'
            $result | Should -Match '"BRANCH"'
            $result | Should -Match '"HAS_GIT"'
        }

        It "includes correct branch name" {
            $featureDir = New-MockFeature -TestDir $script:TestDir
            git checkout -b "001-test-feature" 2>&1 | Out-Null

            $result = & $script:SetupPlanScript -Json | Out-String
            $result | Should -Match "001-test-feature"
        }

        It "shows HAS_GIT as boolean" {
            $featureDir = New-MockFeature -TestDir $script:TestDir
            git checkout -b "001-test-feature" 2>&1 | Out-Null

            $result = & $script:SetupPlanScript -Json | Out-String
            $result | Should -Match '"HAS_GIT":\s*true'
        }
    }

    Context "Non-git support" {
        It "works with SPECIFY_FEATURE environment variable" {
            $featureDir = New-MockFeature -TestDir $script:TestDir

            Remove-Item ".git" -Recurse -Force -ErrorAction SilentlyContinue

            $env:SPECIFY_FEATURE = "001-test-feature"
            # Use -ProjectRoot to override script's repo root detection
            $output = & $script:SetupPlanScript -ProjectRoot $script:TestDir *>&1 | Out-String
            $env:SPECIFY_FEATURE = $null

            ($LASTEXITCODE -eq 0) -or ($output -match "Warning") | Should -Be $true
        }
    }
}
