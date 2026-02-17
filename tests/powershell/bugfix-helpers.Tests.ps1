# Tests for bugfix-helpers.ps1

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:BugfixScript = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "tiles/intent-integrity-kit/skills/iikit-core/scripts/powershell/bugfix-helpers.ps1"
}

# =============================================================================
# --list-features tests (TS-020)
# =============================================================================

Describe "--list-features" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns empty array with no features" {
        $result = & $script:BugfixScript --list-features
        $result | Should -Be "[]"
    }

    It "returns JSON array with features and stages" {
        New-Item -ItemType Directory -Path "specs/001-feature-a" -Force | Out-Null
        "# Spec" | Out-File "specs/001-feature-a/spec.md"
        New-Item -ItemType Directory -Path "specs/002-feature-b" -Force | Out-Null
        "# Spec" | Out-File "specs/002-feature-b/spec.md"
        "# Plan" | Out-File "specs/002-feature-b/plan.md"

        $result = & $script:BugfixScript --list-features
        $result | Should -Match "001-feature-a"
        $result | Should -Match "002-feature-b"
        $result | Should -Match "specified"
        $result | Should -Match "planned"
    }
}

# =============================================================================
# --next-bug-id tests (TS-021, TS-022)
# =============================================================================

Describe "--next-bug-id" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns BUG-001 when no bugs.md exists" {
        New-Item -ItemType Directory -Path "specs/001-test" -Force | Out-Null

        $result = & $script:BugfixScript --next-bug-id (Join-Path $script:TestDir "specs/001-test")
        $result | Should -Be "BUG-001"
    }

    It "returns BUG-003 when bugs.md has BUG-001 and BUG-002" {
        New-Item -ItemType Directory -Path "specs/001-test" -Force | Out-Null
        @(
            "# Bug Reports: test",
            "",
            "## BUG-001",
            "",
            "**Description**: First bug",
            "",
            "## BUG-002",
            "",
            "**Description**: Second bug"
        ) | Out-File "specs/001-test/bugs.md"

        $result = & $script:BugfixScript --next-bug-id (Join-Path $script:TestDir "specs/001-test")
        $result | Should -Be "BUG-003"
    }

    It "handles single bug correctly" {
        New-Item -ItemType Directory -Path "specs/001-test" -Force | Out-Null
        @(
            "# Bug Reports: test",
            "",
            "## BUG-001",
            "",
            "**Description**: Only bug"
        ) | Out-File "specs/001-test/bugs.md"

        $result = & $script:BugfixScript --next-bug-id (Join-Path $script:TestDir "specs/001-test")
        $result | Should -Be "BUG-002"
    }
}

# =============================================================================
# --next-task-ids tests (TS-023)
# =============================================================================

Describe "--next-task-ids" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns T-B001 when no existing T-B tasks" {
        New-Item -ItemType Directory -Path "specs/001-test" -Force | Out-Null
        @(
            "# Tasks",
            "- [ ] T001 Normal task",
            "- [ ] T002 Another task"
        ) | Out-File "specs/001-test/tasks.md"

        $result = & $script:BugfixScript --next-task-ids (Join-Path $script:TestDir "specs/001-test") 3
        $result | Should -Match '"start":"T-B001"'
        $result | Should -Match '"T-B001"'
        $result | Should -Match '"T-B002"'
        $result | Should -Match '"T-B003"'
    }

    It "avoids collision with existing T-B tasks" {
        New-Item -ItemType Directory -Path "specs/001-test" -Force | Out-Null
        @(
            "# Tasks",
            "- [x] T-B001 Investigate root cause for BUG-001",
            "- [x] T-B002 Implement fix for BUG-001",
            "- [x] T-B003 Write regression test for BUG-001"
        ) | Out-File "specs/001-test/tasks.md"

        $result = & $script:BugfixScript --next-task-ids (Join-Path $script:TestDir "specs/001-test") 3
        $result | Should -Match '"start":"T-B004"'
        $result | Should -Match '"T-B004"'
        $result | Should -Match '"T-B005"'
        $result | Should -Match '"T-B006"'
    }

    It "returns T-B001 when no tasks.md exists" {
        New-Item -ItemType Directory -Path "specs/001-test" -Force | Out-Null

        $result = & $script:BugfixScript --next-task-ids (Join-Path $script:TestDir "specs/001-test") 2
        $result | Should -Match '"start":"T-B001"'
        $result | Should -Match '"T-B001"'
        $result | Should -Match '"T-B002"'
    }
}

# =============================================================================
# --validate-feature tests (TS-024)
# =============================================================================

Describe "--validate-feature" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "passes when spec.md exists" {
        $featureDir = New-MockFeature -TestDir $script:TestDir

        $result = & $script:BugfixScript --validate-feature $featureDir
        $result | Should -Match '"valid":true'
    }

    It "fails when directory does not exist" {
        $result = & $script:BugfixScript --validate-feature (Join-Path $script:TestDir "specs/nonexistent") 2>&1
        "$result" | Should -Match '"valid":false'
    }

    It "fails when spec.md missing" {
        New-Item -ItemType Directory -Path "specs/001-no-spec" -Force | Out-Null

        $result = & $script:BugfixScript --validate-feature (Join-Path $script:TestDir "specs/001-no-spec") 2>&1
        "$result" | Should -Match '"valid":false'
        "$result" | Should -Match 'spec.md not found'
    }

    It "reports artifact presence" {
        $featureDir = New-CompleteMockFeature -TestDir $script:TestDir

        $result = & $script:BugfixScript --validate-feature $featureDir
        $result | Should -Match '"valid":true'
        $result | Should -Match '"has_tasks":true'
        $result | Should -Match '"has_tests":true'
    }
}

# =============================================================================
# Error handling tests
# =============================================================================

Describe "error handling" {
    It "unknown subcommand shows error" {
        { & $script:BugfixScript --unknown } | Should -Throw
    }
}
