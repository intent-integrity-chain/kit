# Tests for create-new-feature.ps1

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:CreateScript = Join-Path $Global:ScriptsDir "create-new-feature.ps1"
}

Describe "create-new-feature" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir

        # Initialize git for branch creation
        git init . 2>&1 | Out-Null
        git config user.email "test@test.com"
        git config user.name "Test"
        ".gitkeep" | Out-File ".gitkeep"
        git add .gitkeep
        git commit -m "initial" 2>&1 | Out-Null
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    Context "Basic feature creation" {
        It "creates feature directory" {
            & $script:CreateScript -Json -Description "Add user authentication"

            $dirs = Get-ChildItem -Path "specs" -Directory -Filter "001-*"
            $dirs.Count | Should -BeGreaterThan 0
        }

        It "creates spec.md from template" {
            & $script:CreateScript -Json -Description "Add user authentication"

            $specFile = Get-ChildItem -Path "specs" -Recurse -Filter "spec.md" | Select-Object -First 1
            $specFile | Should -Not -BeNullOrEmpty
        }

        It "outputs JSON with required fields" {
            $result = & $script:CreateScript -Json -Description "Add user authentication" | Out-String

            $result | Should -Match '"BRANCH_NAME"'
            $result | Should -Match '"SPEC_FILE"'
            $result | Should -Match '"FEATURE_NUM"'
            $result | Should -Match '"HAS_GIT"'
        }

        It "creates git branch by default" {
            & $script:CreateScript -Json -Description "Add user authentication"

            $branch = git branch --show-current
            $branch | Should -Match "^001-"
        }
    }

    Context "Branch naming" {
        It "generates clean branch name" {
            $result = & $script:CreateScript -Json -Description "Add user authentication system" | Out-String

            $result | Should -Match "user"
            $result | Should -Match "authentication"
        }

        It "uses ShortName when provided" {
            $result = & $script:CreateScript -Json -ShortName "user-auth" -Description "Add user authentication" | Out-String

            $result | Should -Match "user-auth"
        }

        It "removes stop words from branch name" {
            $result = & $script:CreateScript -Json -Description "I want to add a new feature for the users" | Out-String

            $result | Should -Not -Match "-i-"
            $result | Should -Not -Match "-want-"
            $result | Should -Not -Match "-to-"
        }

        It "handles special characters" {
            $result = & $script:CreateScript -Json -Description "Fix bug #123: user's profile" | Out-String
            $json = $result | ConvertFrom-Json

            $json.BRANCH_NAME | Should -Not -Match "#"
            $json.BRANCH_NAME | Should -Not -Match "'"
            $json.BRANCH_NAME | Should -Not -Match ":"
        }
    }

    Context "Number handling" {
        It "auto-increments feature number" {
            & $script:CreateScript -Json -SkipBranch -Description "First feature"

            git checkout -b "temp-branch" 2>&1 | Out-Null
            $result = & $script:CreateScript -Json -SkipBranch -Description "Second feature" | Out-String

            $result | Should -Match '"FEATURE_NUM":\s*"002"'
        }

        It "respects Number override" {
            $result = & $script:CreateScript -Json -Number 42 -Description "Custom numbered feature" | Out-String

            $result | Should -Match '"FEATURE_NUM":\s*"042"'
        }

        It "pads number to 3 digits" {
            $result = & $script:CreateScript -Json -Number 5 -Description "Padded feature" | Out-String

            $result | Should -Match '"FEATURE_NUM":\s*"005"'
        }
    }

    Context "Skip branch" {
        It "SkipBranch creates directory without branch" {
            $originalBranch = git branch --show-current

            & $script:CreateScript -Json -SkipBranch -Description "No branch feature"

            $currentBranch = git branch --show-current
            $currentBranch | Should -Be $originalBranch

            $dirs = Get-ChildItem -Path "specs" -Directory -Filter "001-*"
            $dirs.Count | Should -BeGreaterThan 0
        }
    }

    Context "Non-git repo" {
        It "works in non-git repo" {
            Remove-Item ".git" -Recurse -Force

            $result = & $script:CreateScript -Json -Description "Feature without git" | Out-String

            $dirs = Get-ChildItem -Path "specs" -Directory -Filter "001-*"
            $dirs.Count | Should -BeGreaterThan 0
            $result | Should -Match '"HAS_GIT":\s*false'
        }
    }

    Context "Branch name length" {
        It "truncates long branch names" {
            $longDesc = ("word " * 100)

            $result = & $script:CreateScript -Json -SkipBranch -Description $longDesc | Out-String
            $json = $result | ConvertFrom-Json

            $json.BRANCH_NAME.Length | Should -BeLessOrEqual 244
        }
    }
}
