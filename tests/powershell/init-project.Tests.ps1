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
}
