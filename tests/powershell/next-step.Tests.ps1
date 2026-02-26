# Tests for next-step.ps1 — single source of truth for next-step determination

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:NextStepScript = Join-Path $Global:ScriptsDir "next-step.ps1"
}

Describe "Argument validation" {
    It "errors without -Phase" {
        { & $script:NextStepScript -Json } | Should -Throw
    }
}

Describe "Phase-based transitions (mandatory path)" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        $env:SPECIFY_FEATURE = "001-test-feature"
    }

    AfterEach {
        Pop-Location
        $env:SPECIFY_FEATURE = $null
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "phase 00 → /iikit-01-specify" {
        $result = & $script:NextStepScript -Phase 00 -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-01-specify"
        $result.next_phase | Should -Be "01"
    }

    It "phase 01 → /iikit-02-plan" {
        $result = & $script:NextStepScript -Phase 01 -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-02-plan"
        $result.next_phase | Should -Be "02"
    }

    It "phase 02 → /iikit-05-tasks when TDD not mandatory" {
        # Replace constitution with no-TDD version
        Copy-Item (Join-Path $Global:FixturesDir "constitution-no-tdd.md") (Join-Path $script:TestDir "CONSTITUTION.md") -Force

        $result = & $script:NextStepScript -Phase 02 -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-05-tasks"
        $result.next_phase | Should -Be "05"
    }

    It "phase 02 → /iikit-04-testify when TDD mandatory" {
        # Default fixture constitution mandates TDD
        $result = & $script:NextStepScript -Phase 02 -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-04-testify"
        $result.next_phase | Should -Be "04"
    }

    It "phase 04 → /iikit-05-tasks" {
        $result = & $script:NextStepScript -Phase 04 -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-05-tasks"
        $result.next_phase | Should -Be "05"
    }

    It "phase 05 → /iikit-07-implement" {
        $result = & $script:NextStepScript -Phase 05 -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-07-implement"
        $result.next_phase | Should -Be "07"
    }

    It "phase 06 → /iikit-07-implement" {
        $result = & $script:NextStepScript -Phase 06 -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-07-implement"
        $result.next_phase | Should -Be "07"
    }

    It "phase 08 → null (terminal)" {
        $result = & $script:NextStepScript -Phase 08 -Json | ConvertFrom-Json
        $result.next_step | Should -BeNullOrEmpty
        $result.next_phase | Should -BeNullOrEmpty
    }

    It "bugfix → /iikit-07-implement always" {
        $result = & $script:NextStepScript -Phase bugfix -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-07-implement"
        $result.next_phase | Should -Be "07"
    }
}

Describe "Artifact-state fallback" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        $env:SPECIFY_FEATURE = "001-test-feature"
    }

    AfterEach {
        Pop-Location
        $env:SPECIFY_FEATURE = $null
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "status → /iikit-00-constitution when no constitution" {
        Remove-Item "CONSTITUTION.md"

        $result = & $script:NextStepScript -Phase status -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-00-constitution"
        $result.next_phase | Should -Be "00"
    }

    It "status → /iikit-01-specify when no feature" {
        $result = & $script:NextStepScript -Phase status -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-01-specify"
        $result.next_phase | Should -Be "01"
    }

    It "status → /iikit-02-plan when spec exists but no plan" {
        $featureDir = Join-Path $script:TestDir "specs/001-test-feature"
        New-Item -ItemType Directory -Path $featureDir -Force | Out-Null
        Copy-Item (Join-Path $Global:FixturesDir "spec.md") (Join-Path $featureDir "spec.md")
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir ".specify") -Force | Out-Null
        "001-test-feature" | Set-Content (Join-Path $script:TestDir ".specify/active-feature") -NoNewline

        $result = & $script:NextStepScript -Phase status -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-02-plan"
    }

    It "status → /iikit-05-tasks when plan exists but no tasks" {
        $featureDir = New-MockFeature -TestDir $script:TestDir
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir ".specify") -Force | Out-Null
        "001-test-feature" | Set-Content (Join-Path $script:TestDir ".specify/active-feature") -NoNewline

        $result = & $script:NextStepScript -Phase status -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-05-tasks"
    }

    It "status → /iikit-07-implement when tasks exist and incomplete" {
        $featureDir = New-CompleteMockFeature -TestDir $script:TestDir
        New-Item -ItemType Directory -Path (Join-Path $script:TestDir ".specify") -Force | Out-Null
        "001-test-feature" | Set-Content (Join-Path $script:TestDir ".specify/active-feature") -NoNewline

        $result = & $script:NextStepScript -Phase status -Json | ConvertFrom-Json
        $result.next_step | Should -Be "/iikit-07-implement"
    }
}

Describe "JSON output structure" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        $env:SPECIFY_FEATURE = "001-test-feature"
    }

    AfterEach {
        Pop-Location
        $env:SPECIFY_FEATURE = $null
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "output is valid JSON with all required fields" {
        $result = & $script:NextStepScript -Phase 01 -Json | ConvertFrom-Json
        $result.current_phase | Should -Be "01"
        $result.next_step | Should -Not -BeNullOrEmpty
        $result.next_phase | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain "clear_before"
        $result.PSObject.Properties.Name | Should -Contain "clear_after"
        $result.PSObject.Properties.Name | Should -Contain "model_tier"
        $result.PSObject.Properties.Name | Should -Contain "feature_stage"
        $result.PSObject.Properties.Name | Should -Contain "tdd_mandatory"
        $result.PSObject.Properties.Name | Should -Contain "alt_steps"
    }
}

Describe "Clear logic" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        $env:SPECIFY_FEATURE = "001-test-feature"
    }

    AfterEach {
        Pop-Location
        $env:SPECIFY_FEATURE = $null
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "clear_after true for phase 02 (plan consumed context)" {
        $result = & $script:NextStepScript -Phase 02 -Json | ConvertFrom-Json
        $result.clear_after | Should -BeTrue
    }

    It "clear_after true for phase 07 (implementation consumed context)" {
        $result = & $script:NextStepScript -Phase 07 -Json | ConvertFrom-Json
        $result.clear_after | Should -BeTrue
    }

    It "clear_after true for clarify (Q&A consumed context)" {
        $result = & $script:NextStepScript -Phase clarify -Json | ConvertFrom-Json
        $result.clear_after | Should -BeTrue
    }

    It "clear_after false for phase 00" {
        $result = & $script:NextStepScript -Phase 00 -Json | ConvertFrom-Json
        $result.clear_after | Should -BeFalse
    }

    It "clear_before true when next is plan (02)" {
        $result = & $script:NextStepScript -Phase 01 -Json | ConvertFrom-Json
        $result.clear_before | Should -BeTrue
    }

    It "clear_before true when next is implement (07)" {
        $result = & $script:NextStepScript -Phase 05 -Json | ConvertFrom-Json
        $result.clear_before | Should -BeTrue
    }

    It "clear_before false when next is specify (01)" {
        $result = & $script:NextStepScript -Phase 00 -Json | ConvertFrom-Json
        $result.clear_before | Should -BeFalse
    }
}

Describe "Model tier" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        $env:SPECIFY_FEATURE = "001-test-feature"
    }

    AfterEach {
        Pop-Location
        $env:SPECIFY_FEATURE = $null
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "heavy for plan (02)" {
        $result = & $script:NextStepScript -Phase 01 -Json | ConvertFrom-Json
        $result.model_tier | Should -Be "heavy"
    }

    It "medium for specify (01)" {
        $result = & $script:NextStepScript -Phase 00 -Json | ConvertFrom-Json
        $result.model_tier | Should -Be "medium"
    }

    It "heavy for implement (07)" {
        $result = & $script:NextStepScript -Phase 05 -Json | ConvertFrom-Json
        $result.model_tier | Should -Be "heavy"
    }

    It "null when workflow complete" {
        $result = & $script:NextStepScript -Phase 08 -Json | ConvertFrom-Json
        $result.model_tier | Should -BeNullOrEmpty
    }
}

Describe "TDD determination" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        $env:SPECIFY_FEATURE = "001-test-feature"
    }

    AfterEach {
        Pop-Location
        $env:SPECIFY_FEATURE = $null
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "tdd_mandatory true with TDD constitution" {
        $result = & $script:NextStepScript -Phase 00 -Json | ConvertFrom-Json
        $result.tdd_mandatory | Should -BeTrue
    }

    It "tdd_mandatory false with no-TDD constitution" {
        Copy-Item (Join-Path $Global:FixturesDir "constitution-no-tdd.md") (Join-Path $script:TestDir "CONSTITUTION.md") -Force

        $result = & $script:NextStepScript -Phase 00 -Json | ConvertFrom-Json
        $result.tdd_mandatory | Should -BeFalse
    }
}

Describe "Alt steps" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
        $env:SPECIFY_FEATURE = "001-test-feature"
    }

    AfterEach {
        Pop-Location
        $env:SPECIFY_FEATURE = $null
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "empty when no artifacts" {
        $result = & $script:NextStepScript -Phase 00 -Json | ConvertFrom-Json
        $result.alt_steps.Count | Should -Be 0
    }

    It "includes checklist after plan (phase 02) when TDD not mandatory" {
        Copy-Item (Join-Path $Global:FixturesDir "constitution-no-tdd.md") (Join-Path $script:TestDir "CONSTITUTION.md") -Force

        $result = & $script:NextStepScript -Phase 02 -Json | ConvertFrom-Json
        $result.alt_steps.step | Should -Contain "/iikit-03-checklist"
    }

    It "includes analyze after tasks (phase 05)" {
        $result = & $script:NextStepScript -Phase 05 -Json | ConvertFrom-Json
        $result.alt_steps.step | Should -Contain "/iikit-06-analyze"
    }
}
