# Tests for check-prerequisites.ps1

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:CheckScript = Join-Path $Global:ScriptsDir "check-prerequisites.ps1"
}

Describe "Paths-only mode" {
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

    It "-PathsOnly returns paths without validation" {
        $result = & $script:CheckScript -PathsOnly | Out-String
        $result | Should -Match "REPO_ROOT:"
        $result | Should -Match "BRANCH:"
        $result | Should -Match "FEATURE_DIR:"
    }

    It "-PathsOnly -Json returns JSON paths" {
        $result = & $script:CheckScript -PathsOnly -Json
        $json = $result | ConvertFrom-Json
        $json.REPO_ROOT | Should -Not -BeNullOrEmpty
        $json.BRANCH | Should -Not -BeNullOrEmpty
        $json.FEATURE_DIR | Should -Not -BeNullOrEmpty
    }

    It "-PathsOnly succeeds even without feature dir" {
        { & $script:CheckScript -PathsOnly } | Should -Not -Throw
    }
}

Describe "Validation mode" {
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

    It "fails when feature dir missing" {
        $result = & $script:CheckScript -Json 2>&1 | Out-String
        $result | Should -Match "Feature directory not found"
    }

    It "fails when constitution missing" {
        New-MockFeature -TestDir $script:TestDir
        Remove-Item "CONSTITUTION.md"

        $result = & $script:CheckScript -Json 2>&1 | Out-String
        $result | Should -Match "Constitution"
    }

    It "succeeds with spec and plan" {
        New-MockFeature -TestDir $script:TestDir

        { & $script:CheckScript -Json } | Should -Not -Throw
    }
}

Describe "Task requirement" {
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

    It "-RequireTasks fails without tasks.md" {
        New-MockFeature -TestDir $script:TestDir

        $result = & $script:CheckScript -Json -RequireTasks 2>&1 | Out-String
        $result | Should -Match "tasks.md"
    }

    It "-RequireTasks succeeds with tasks.md" {
        New-CompleteMockFeature -TestDir $script:TestDir

        { & $script:CheckScript -Json -RequireTasks } | Should -Not -Throw
    }
}

Describe "Available docs" {
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

    It "lists available docs in JSON" {
        $featureDir = New-MockFeature -TestDir $script:TestDir

        # Add some optional docs
        "# Research" | Out-File (Join-Path $featureDir "research.md")
        New-Item -ItemType Directory -Path (Join-Path $featureDir "contracts") -Force | Out-Null
        "openapi: 3.0.0" | Out-File (Join-Path $featureDir "contracts/api.yaml")

        $result = & $script:CheckScript -Json | ConvertFrom-Json
        $result.AVAILABLE_DOCS | Should -Contain "research.md"
        $result.AVAILABLE_DOCS | Should -Contain "contracts/"
    }

    It "-IncludeTasks adds tasks to available docs" {
        New-CompleteMockFeature -TestDir $script:TestDir

        $result = & $script:CheckScript -Json -IncludeTasks | ConvertFrom-Json
        $result.AVAILABLE_DOCS | Should -Contain "tasks.md"
    }
}

Describe "JSON output" {
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

    It "JSON output is valid JSON" {
        New-MockFeature -TestDir $script:TestDir

        $result = & $script:CheckScript -Json
        { $result | ConvertFrom-Json } | Should -Not -Throw
    }

    It "JSON contains FEATURE_DIR" {
        New-MockFeature -TestDir $script:TestDir

        $result = & $script:CheckScript -Json | ConvertFrom-Json
        $result.FEATURE_DIR | Should -Match "001-test-feature"
    }
}

Describe "Help" {
    It "-Help shows usage" {
        $result = & $script:CheckScript -Help | Out-String
        $result | Should -Match "Usage:"
        $result | Should -Match "-Json"
        $result | Should -Match "-RequireTasks"
    }
}
