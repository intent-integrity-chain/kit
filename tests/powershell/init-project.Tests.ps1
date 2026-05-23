# Tests for init-project.ps1

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:InitScript = Join-Path $Global:ScriptsDir "init-project.ps1"
}

Describe "init-project" {
    BeforeEach {
        $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "iikit-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        if (Test-Path $script:TestDir) {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Validation" {
        It "fails without .specify directory" {
            { & $script:InitScript } | Should -Throw
        }

        It "returns error JSON without .specify" {
            $result = & $script:InitScript -Json 2>&1 | Out-String
            $result | Should -Match '"success":\s*false'
        }
    }

    Context "Git initialization" {
        BeforeEach {
            New-Item -ItemType Directory -Path ".specify" -Force | Out-Null
        }

        It "initializes git in new project" {
            & $script:InitScript
            Test-Path ".git" | Should -Be $true
        }

        It "reports already initialized for existing git repo" {
            git init . 2>&1 | Out-Null
            $output = & $script:InitScript 2>&1 | Out-String
            $output | Should -Match "already"
        }

        It "JSON shows git_initialized true for new repo" {
            $result = & $script:InitScript -Json | Out-String
            $result | Should -Match '"git_initialized":\s*true'
            $result | Should -Match '"git_status":\s*"initialized"'
        }

        It "JSON shows git_initialized false for existing repo" {
            git init . 2>&1 | Out-Null
            $result = & $script:InitScript -Json | Out-String
            $result | Should -Match '"git_initialized":\s*false'
            $result | Should -Match '"git_status":\s*"already_initialized"'
        }
    }

    Context "Constitution commit" {
        BeforeEach {
            New-Item -ItemType Directory -Path ".specify" -Force | Out-Null
            "# Constitution" | Out-File "CONSTITUTION.md"
            # Pre-initialize git so we can configure user (Windows CI may lack global config)
            git init . 2>&1 | Out-Null
            git config user.email "test@test.com"
            git config user.name "Test"
        }

        It "commits constitution with -CommitConstitution" {
            & $script:InitScript -CommitConstitution
            $log = git log --oneline -1 2>&1
            $log | Should -Match "constitution"
        }

        It "also commits README if exists" {
            "# README" | Out-File "README.md"
            & $script:InitScript -CommitConstitution
            $files = (git ls-files 2>&1) -join "`n"
            $files | Should -Match "CONSTITUTION.md"
            $files | Should -Match "README.md"
        }

        It "JSON shows constitution_committed true" {
            $result = & $script:InitScript -Json -CommitConstitution | Out-String
            $result | Should -Match '"constitution_committed":\s*true'
        }
    }

    Context "pre-commit.d extension point" {
        BeforeEach {
            New-Item -ItemType Directory -Path ".specify" -Force | Out-Null
        }

        It "creates pre-commit.d directory with marker README" {
            & $script:InitScript | Out-Null
            Test-Path ".git/hooks/pre-commit.d" | Should -Be $true
            Test-Path ".git/hooks/pre-commit.d/README" | Should -Be $true
            (Get-Content ".git/hooks/pre-commit.d/README" -Raw) | Should -Match 'IIKIT-PRE-COMMIT-D'
        }

        It "JSON reports pre_commit_d_provisioned true on fresh init" {
            $result = & $script:InitScript -Json | Out-String
            $result | Should -Match '"pre_commit_d_provisioned":\s*true'
        }

        It "preserves an existing README on re-run and reports provisioned false" {
            & $script:InitScript | Out-Null
            Add-Content -Path ".git/hooks/pre-commit.d/README" -Value "user customization"
            $result = & $script:InitScript -Json | Out-String
            (Get-Content ".git/hooks/pre-commit.d/README" -Raw) | Should -Match 'user customization'
            $result | Should -Match '"pre_commit_d_provisioned":\s*false'
        }

        It "preserves user scripts in pre-commit.d on re-run" {
            & $script:InitScript | Out-Null
            "#!/bin/sh" | Set-Content ".git/hooks/pre-commit.d/prettier"
            & $script:InitScript | Out-Null
            Test-Path ".git/hooks/pre-commit.d/prettier" | Should -Be $true
        }
    }

    Context "Linked-worktree support" {
        It "installs hooks at the main repo's hooks dir when run from a worktree" {
            Pop-Location

            $mainDir = Join-Path $script:TestDir "main"
            $wtDir = Join-Path $script:TestDir "wt"
            New-Item -ItemType Directory -Path $mainDir -Force | Out-Null

            Push-Location $mainDir
            git init -q . 2>&1 | Out-Null
            git config user.email "test@test.com"
            git config user.name "Test"
            git commit -q --allow-empty -m "init" 2>&1 | Out-Null
            git worktree add -q $wtDir -b feature 2>&1 | Out-Null
            Pop-Location

            Push-Location $wtDir
            New-Item -ItemType Directory -Path ".specify" -Force | Out-Null

            $result = & $script:InitScript -Json | Out-String

            # Hooks land in the main repo's hooks dir, not the worktree's `.git` (a file)
            (Test-Path (Join-Path $mainDir ".git/hooks/pre-commit")) | Should -Be $true
            (Test-Path (Join-Path $mainDir ".git/hooks/pre-commit.d/README")) | Should -Be $true
            (Get-Content (Join-Path $mainDir ".git/hooks/pre-commit") -Raw) | Should -Match 'IIKIT-PRE-COMMIT'

            $result | Should -Match '"hook_installed":\s*true'
            $result | Should -Match '"pre_commit_d_provisioned":\s*true'

            # Worktree's `.git` file is untouched (it's a file, not a directory)
            (Test-Path (Join-Path $wtDir ".git")) | Should -Be $true
        }
    }
}
