# Tests for set-active-feature.ps1

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $Global:SetScript = Join-Path $Global:ScriptsDir "powershell" "set-active-feature.ps1"
}

Describe "set-active-feature" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir

        # Create test features
        New-Item -ItemType Directory -Path "specs/001-user-auth" -Force | Out-Null
        "# Spec" | Out-File "specs/001-user-auth/spec.md"
        New-Item -ItemType Directory -Path "specs/002-payment-flow" -Force | Out-Null
        "# Spec" | Out-File "specs/002-payment-flow/spec.md"
        "# Plan" | Out-File "specs/002-payment-flow/plan.md"
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "selects by number 1" {
        $result = & $Global:SetScript -Json -Selector "1" 2>&1
        $result | Should -Match "001-user-auth"
    }

    It "selects by full directory name" {
        $result = & $Global:SetScript -Json -Selector "001-user-auth" 2>&1
        $result | Should -Match "001-user-auth"
    }

    It "selects by partial name" {
        $result = & $Global:SetScript -Json -Selector "payment" 2>&1
        $result | Should -Match "002-payment-flow"
    }

    It "shows help" {
        $result = & $Global:SetScript -Help 2>&1
        "$result" | Should -Match "Usage:"
    }
}
