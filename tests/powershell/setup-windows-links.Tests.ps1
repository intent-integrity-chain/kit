# Tests for setup-windows-links.ps1
# These tests only run on Windows as the script uses Windows-specific APIs

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:SetupScript = Join-Path $Global:ScriptsDir "setup-windows-links.ps1"
    $script:RunningOnWindows = $PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows
}

BeforeDiscovery {
    $script:SkipNonWindows = -not ($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows)
}

Describe "setup-windows-links" -Skip:$script:SkipNonWindows {
    BeforeEach {
        $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "iikit-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        Push-Location $script:TestDir

        # Create minimal project structure
        New-Item -ItemType Directory -Path ".claude/skills" -Force | Out-Null
        "# Test skill" | Out-File ".claude/skills/test-skill.md"
        "# AGENTS.md" | Out-File "AGENTS.md"
    }

    AfterEach {
        Pop-Location
        if (Test-Path $script:TestDir) {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Directory symlinks" {
        It "creates .codex/skills link" {
            & $script:SetupScript -ProjectRoot $script:TestDir
            Test-Path ".codex/skills" | Should -Be $true
        }

        It "creates .gemini/skills link" {
            & $script:SetupScript -ProjectRoot $script:TestDir
            Test-Path ".gemini/skills" | Should -Be $true
        }

        It "creates .opencode/skills link" {
            & $script:SetupScript -ProjectRoot $script:TestDir
            Test-Path ".opencode/skills" | Should -Be $true
        }

        It "links point to correct content" {
            & $script:SetupScript -ProjectRoot $script:TestDir
            Test-Path ".codex/skills/test-skill.md" | Should -Be $true
            Test-Path ".gemini/skills/test-skill.md" | Should -Be $true
            Test-Path ".opencode/skills/test-skill.md" | Should -Be $true
        }
    }

    Context "File symlinks" {
        It "creates CLAUDE.md link" {
            & $script:SetupScript -ProjectRoot $script:TestDir
            Test-Path "CLAUDE.md" | Should -Be $true
        }

        It "creates GEMINI.md link" {
            & $script:SetupScript -ProjectRoot $script:TestDir
            Test-Path "GEMINI.md" | Should -Be $true
        }

        It "file links have same content as AGENTS.md" {
            & $script:SetupScript -ProjectRoot $script:TestDir
            (Get-Content "CLAUDE.md" -Raw) | Should -Be (Get-Content "AGENTS.md" -Raw)
            (Get-Content "GEMINI.md" -Raw) | Should -Be (Get-Content "AGENTS.md" -Raw)
        }
    }

    Context "Skip behavior" {
        It "skips existing links without -Force" {
            & $script:SetupScript -ProjectRoot $script:TestDir
            $output = & $script:SetupScript -ProjectRoot $script:TestDir *>&1 | Out-String
            $output | Should -Match "SKIP"
        }
    }

    Context "Force flag" {
        It "-Force overwrites existing links" {
            & $script:SetupScript -ProjectRoot $script:TestDir
            $output = & $script:SetupScript -Force -ProjectRoot $script:TestDir *>&1 | Out-String
            $output | Should -Match "Removing existing link"
        }
    }

    Context "Output" {
        It "shows completion message" {
            $output = & $script:SetupScript -ProjectRoot $script:TestDir *>&1 | Out-String
            $output | Should -Match "Setup complete|completed"
        }

        It "shows project root" {
            $output = & $script:SetupScript -ProjectRoot $script:TestDir *>&1 | Out-String
            $output | Should -Match "Project root"
        }
    }
}
