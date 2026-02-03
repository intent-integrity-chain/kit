# Tests for verify-test-execution.ps1

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:VerifyScript = Join-Path $Global:ScriptsDir "verify-test-execution.ps1"
}

Describe "count-expected" {
    It "counts TS-XXX patterns" {
        $result = & $script:VerifyScript count-expected (Join-Path $Global:FixturesDir "test-specs.md")
        $result | Should -Be 3
    }

    It "returns 0 for missing file" {
        $result = & $script:VerifyScript count-expected "/nonexistent/test-specs.md"
        $result | Should -Be 0
    }

    It "returns 0 for file without test specs" {
        $script:TestDir = New-TestDirectory
        "# No test specs here" | Out-File (Join-Path $script:TestDir "empty.md")
        $result = & $script:VerifyScript count-expected (Join-Path $script:TestDir "empty.md")
        $result | Should -Be 0
        Remove-TestDirectory -TestDir $script:TestDir
    }
}

Describe "parse-output - Jest/Vitest" {
    It "parses Jest output" {
        $output = "Tests: 5 passed, 2 failed, 7 total"
        $result = & $script:VerifyScript parse-output $output | ConvertFrom-Json
        $result.passed | Should -Be 5
        $result.failed | Should -Be 2
        $result.total | Should -Be 7
    }

    It "parses Vitest output" {
        $output = "Tests: 10 passed, 0 failed, 10 total"
        $result = & $script:VerifyScript parse-output $output | ConvertFrom-Json
        $result.passed | Should -Be 10
        $result.failed | Should -Be 0
        $result.total | Should -Be 10
    }
}

Describe "parse-output - Pytest" {
    It "parses Pytest output" {
        $output = "====== 8 passed in 1.23s ======"
        $result = & $script:VerifyScript parse-output $output | ConvertFrom-Json
        $result.passed | Should -Be 8
        $result.failed | Should -Be 0
    }

    It "parses Pytest output with failures" {
        $output = "====== 5 passed, 3 failed in 2.45s ======"
        $result = & $script:VerifyScript parse-output $output | ConvertFrom-Json
        $result.passed | Should -Be 5
        $result.failed | Should -Be 3
    }
}

Describe "parse-output - Go test" {
    It "parses Go test output" {
        $output = @"
--- PASS: TestOne (0.00s)
--- PASS: TestTwo (0.01s)
--- FAIL: TestThree (0.00s)
ok      example.com/pkg     0.123s
"@
        $result = & $script:VerifyScript parse-output $output | ConvertFrom-Json
        $result.passed | Should -Be 2
        $result.failed | Should -Be 1
    }
}

Describe "parse-output - Mocha" {
    It "parses Mocha output" {
        $output = @"
  12 passing (3s)
  2 failing
"@
        $result = & $script:VerifyScript parse-output $output | ConvertFrom-Json
        $result.passed | Should -Be 12
        $result.failed | Should -Be 2
    }
}

Describe "parse-output - Playwright" {
    It "parses Playwright output" {
        $output = "  6 passed (5.2s)"
        $result = & $script:VerifyScript parse-output $output | ConvertFrom-Json
        $result.passed | Should -Be 6
    }
}

Describe "verify" {
    It "returns PASS when all tests pass" {
        $output = "Tests: 3 passed, 0 failed, 3 total"
        $result = & $script:VerifyScript verify (Join-Path $Global:FixturesDir "test-specs.md") $output | ConvertFrom-Json
        $result.status | Should -Be "PASS"
    }

    It "returns TESTS_FAILING when tests fail" {
        $output = "Tests: 2 passed, 1 failed, 3 total"
        $result = & $script:VerifyScript verify (Join-Path $Global:FixturesDir "test-specs.md") $output | ConvertFrom-Json
        $result.status | Should -Be "TESTS_FAILING"
    }

    It "returns INCOMPLETE when fewer tests run" {
        $output = "Tests: 1 passed, 0 failed, 1 total"
        $result = & $script:VerifyScript verify (Join-Path $Global:FixturesDir "test-specs.md") $output | ConvertFrom-Json
        $result.status | Should -Be "INCOMPLETE"
    }

    It "returns NO_TESTS_RUN for unrecognized output" {
        $output = "Some random output that doesn't look like test results"
        $result = & $script:VerifyScript verify (Join-Path $Global:FixturesDir "test-specs.md") $output | ConvertFrom-Json
        $result.status | Should -Be "NO_TESTS_RUN"
    }

    It "includes expected count in output" {
        $output = "Tests: 3 passed, 0 failed, 3 total"
        $result = & $script:VerifyScript verify (Join-Path $Global:FixturesDir "test-specs.md") $output | ConvertFrom-Json
        $result.expected | Should -Be 3
    }
}
