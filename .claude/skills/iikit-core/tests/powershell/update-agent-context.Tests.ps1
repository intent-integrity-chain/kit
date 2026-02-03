# Tests for update-agent-context.ps1

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    . "$Global:ScriptsDir/common.ps1"
    $script:UpdateScript = Join-Path $Global:ScriptsDir "update-agent-context.ps1"
}

Describe "update-agent-context" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir

        # Initialize git
        git init . 2>&1 | Out-Null
        git config user.email "test@test.com"
        git config user.name "Test"

        # Create feature with plan
        $featureDir = New-MockFeature -TestDir $script:TestDir

        # Create plan.md with expected format
        @"
# Implementation Plan

## Technical Context

**Language/Version**: Python 3.11
**Primary Dependencies**: FastAPI, SQLAlchemy
**Storage**: PostgreSQL
**Project Type**: web-api

## Architecture
Standard REST API architecture.
"@ | Out-File (Join-Path $featureDir "plan.md")

        git checkout -b "001-test-feature" 2>&1 | Out-Null
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    Context "Prerequisites" {
        It "fails without plan.md" {
            Remove-Item "specs/001-test-feature/plan.md" -ErrorAction SilentlyContinue
            # Script exits with error but doesn't throw - check exit behavior
            $output = & $script:UpdateScript 2>&1 *>&1 | Out-String
            $output | Should -Match "ERROR.*plan.md"
        }

        It "succeeds with valid plan.md" {
            { & $script:UpdateScript } | Should -Not -Throw
        }
    }

    Context "Plan parsing" {
        It "extracts language from plan" {
            # Capture all streams including Write-Host (stream 6)
            $output = & $script:UpdateScript *>&1 | Out-String
            $output | Should -Match "Python"
        }

        It "extracts framework from plan" {
            $output = & $script:UpdateScript *>&1 | Out-String
            $output | Should -Match "FastAPI"
        }

        It "extracts database from plan" {
            $output = & $script:UpdateScript *>&1 | Out-String
            $output | Should -Match "PostgreSQL"
        }
    }

    Context "Agent file creation" {
        It "creates CLAUDE.md when none exists" {
            Remove-Item "CLAUDE.md" -ErrorAction SilentlyContinue
            Remove-Item "GEMINI.md" -ErrorAction SilentlyContinue
            Remove-Item "AGENTS.md" -ErrorAction SilentlyContinue

            & $script:UpdateScript

            Test-Path "CLAUDE.md" | Should -Be $true
        }

        It "updates existing agent files" {
            "# Existing" | Out-File "CLAUDE.md"

            $output = & $script:UpdateScript *>&1 | Out-String
            $output | Should -Match "Updated"
        }
    }

    Context "Specific agent types" {
        It "claude updates only CLAUDE.md" {
            Remove-Item "CLAUDE.md" -ErrorAction SilentlyContinue
            Remove-Item "GEMINI.md" -ErrorAction SilentlyContinue
            Remove-Item "AGENTS.md" -ErrorAction SilentlyContinue

            & $script:UpdateScript -AgentType claude

            Test-Path "CLAUDE.md" | Should -Be $true
        }

        It "gemini updates only GEMINI.md" {
            Remove-Item "CLAUDE.md" -ErrorAction SilentlyContinue
            Remove-Item "GEMINI.md" -ErrorAction SilentlyContinue
            Remove-Item "AGENTS.md" -ErrorAction SilentlyContinue

            & $script:UpdateScript -AgentType gemini

            Test-Path "GEMINI.md" | Should -Be $true
        }

        It "codex updates AGENTS.md" {
            Remove-Item "CLAUDE.md" -ErrorAction SilentlyContinue
            Remove-Item "GEMINI.md" -ErrorAction SilentlyContinue
            Remove-Item "AGENTS.md" -ErrorAction SilentlyContinue

            & $script:UpdateScript -AgentType codex

            Test-Path "AGENTS.md" | Should -Be $true
        }

        It "rejects unknown agent type" {
            # PowerShell ValidateSet throws ParameterBindingValidationException
            { & $script:UpdateScript -AgentType "unknown-agent" } | Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException])
        }
    }

    Context "Output" {
        It "shows success message" {
            $output = & $script:UpdateScript *>&1 | Out-String
            $output | Should -Match "completed successfully"
        }

        It "shows feature name" {
            $output = & $script:UpdateScript *>&1 | Out-String
            $output | Should -Match "001-test-feature"
        }
    }

    Context "Edge cases" {
        It "handles NEEDS CLARIFICATION in plan" {
            @"
# Implementation Plan

**Language/Version**: NEEDS CLARIFICATION
**Primary Dependencies**: N/A
**Storage**: N/A
"@ | Out-File "specs/001-test-feature/plan.md"

            { & $script:UpdateScript } | Should -Not -Throw
        }
    }
}
