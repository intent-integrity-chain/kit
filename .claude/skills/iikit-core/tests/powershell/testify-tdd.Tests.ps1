# Tests for testify-tdd.ps1 functions

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:TestifyScript = Join-Path $Global:ScriptsDir "testify-tdd.ps1"
}

Describe "TDD Assessment" {
    It "returns mandatory for MUST TDD" {
        $result = & $script:TestifyScript assess-tdd (Join-Path $Global:FixturesDir "constitution.md")
        $json = $result | ConvertFrom-Json
        $json.determination | Should -Be "mandatory"
        $json.confidence | Should -Be "high"
    }

    It "returns optional for no TDD indicators" {
        $result = & $script:TestifyScript assess-tdd (Join-Path $Global:FixturesDir "constitution-no-tdd.md")
        $json = $result | ConvertFrom-Json
        $json.determination | Should -Be "optional"
    }

    It "returns forbidden for TDD prohibition" {
        $result = & $script:TestifyScript assess-tdd (Join-Path $Global:FixturesDir "constitution-forbidden-tdd.md")
        $json = $result | ConvertFrom-Json
        $json.determination | Should -Be "forbidden"
    }

    It "returns error for missing file" {
        $result = & $script:TestifyScript assess-tdd "/nonexistent/constitution.md"
        $json = $result | ConvertFrom-Json
        $json.error | Should -Not -BeNullOrEmpty
    }
}

Describe "get-tdd-determination" {
    It "returns just the determination" {
        $result = & $script:TestifyScript get-tdd-determination (Join-Path $Global:FixturesDir "constitution.md")
        $result | Should -Be "mandatory"
    }

    It "returns unknown for missing file" {
        $result = & $script:TestifyScript get-tdd-determination "/nonexistent/constitution.md"
        $result | Should -Be "unknown"
    }
}

Describe "Scenario Counting" {
    It "counts Given/When patterns" {
        $result = & $script:TestifyScript count-scenarios (Join-Path $Global:FixturesDir "spec.md")
        $result | Should -BeGreaterOrEqual 3
    }

    It "returns 0 for missing file" {
        $result = & $script:TestifyScript count-scenarios "/nonexistent/spec.md"
        $result | Should -Be 0
    }

    It "has-scenarios returns true for spec with scenarios" {
        $result = & $script:TestifyScript has-scenarios (Join-Path $Global:FixturesDir "spec.md")
        $result | Should -Be "true"
    }

    It "has-scenarios returns false for spec without scenarios" {
        $result = & $script:TestifyScript has-scenarios (Join-Path $Global:FixturesDir "spec-incomplete.md")
        $result | Should -Be "false"
    }
}

Describe "Assertion Extraction" {
    It "extracts Given/When/Then lines" {
        $result = & $script:TestifyScript extract-assertions (Join-Path $Global:FixturesDir "test-specs.md")
        $result | Should -Match "\*\*Given\*\*:"
        $result | Should -Match "\*\*When\*\*:"
        $result | Should -Match "\*\*Then\*\*:"
    }

    It "returns empty for missing file" {
        $result = & $script:TestifyScript extract-assertions "/nonexistent/test-specs.md"
        $result | Should -BeNullOrEmpty
    }
}

Describe "Hash Computation" {
    It "returns consistent hash" {
        $hash1 = & $script:TestifyScript compute-hash (Join-Path $Global:FixturesDir "test-specs.md")
        $hash2 = & $script:TestifyScript compute-hash (Join-Path $Global:FixturesDir "test-specs.md")
        $hash1 | Should -Be $hash2
    }

    It "returns NO_ASSERTIONS for file without assertions" {
        $script:TestDir = New-TestDirectory
        "# Empty test specs" | Out-File (Join-Path $script:TestDir "empty-test-specs.md")
        $result = & $script:TestifyScript compute-hash (Join-Path $script:TestDir "empty-test-specs.md")
        $result | Should -Be "NO_ASSERTIONS"
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns 64-char hex string" {
        $result = & $script:TestifyScript compute-hash (Join-Path $Global:FixturesDir "test-specs.md")
        $result.Length | Should -Be 64
    }
}

Describe "Hash Storage and Verification" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        $script:ContextFile = Join-Path $script:TestDir ".specify/context.json"
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "store-hash creates context file and stores hash" {
        $result = & $script:TestifyScript store-hash (Join-Path $Global:FixturesDir "test-specs.md") $script:ContextFile

        Test-Path $script:ContextFile | Should -Be $true
        $content = Get-Content $script:ContextFile -Raw
        $content | Should -Match '"assertion_hash"'
        $content | Should -Match '"generated_at"'
    }

    It "verify-hash returns valid for matching hash" {
        & $script:TestifyScript store-hash (Join-Path $Global:FixturesDir "test-specs.md") $script:ContextFile

        $result = & $script:TestifyScript verify-hash (Join-Path $Global:FixturesDir "test-specs.md") $script:ContextFile
        $result | Should -Be "valid"
    }

    It "verify-hash returns missing for no context file" {
        $result = & $script:TestifyScript verify-hash (Join-Path $Global:FixturesDir "test-specs.md") "/nonexistent/context.json"
        $result | Should -Be "missing"
    }

    It "verify-hash returns invalid for modified assertions" {
        $testSpecs = Join-Path $script:TestDir "test-specs.md"
        Copy-Item (Join-Path $Global:FixturesDir "test-specs.md") $testSpecs

        & $script:TestifyScript store-hash $testSpecs $script:ContextFile

        # Modify an assertion
        Add-Content -Path $testSpecs -Value "**Given**: modified assertion"

        $result = & $script:TestifyScript verify-hash $testSpecs $script:ContextFile
        $result | Should -Be "invalid"
    }
}

Describe "Comprehensive Check" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
        $script:ContextFile = Join-Path $script:TestDir ".specify/context.json"
        $script:TestSpecs = Join-Path $script:TestDir "test-specs.md"
        Copy-Item (Join-Path $Global:FixturesDir "test-specs.md") $script:TestSpecs
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns PASS for valid setup" {
        & $script:TestifyScript store-hash $script:TestSpecs $script:ContextFile

        $result = & $script:TestifyScript comprehensive-check $script:TestSpecs $script:ContextFile (Join-Path $Global:FixturesDir "constitution.md")
        $json = $result | ConvertFrom-Json
        $json.overall_status | Should -Be "PASS"
    }

    It "returns BLOCKED for tampered assertions" {
        & $script:TestifyScript store-hash $script:TestSpecs $script:ContextFile

        # Tamper with assertions
        Add-Content -Path $script:TestSpecs -Value "**Then**: tampered assertion"

        $result = & $script:TestifyScript comprehensive-check $script:TestSpecs $script:ContextFile (Join-Path $Global:FixturesDir "constitution.md")
        $json = $result | ConvertFrom-Json
        $json.overall_status | Should -Be "BLOCKED"
    }

    It "includes TDD determination" {
        & $script:TestifyScript store-hash $script:TestSpecs $script:ContextFile

        $result = & $script:TestifyScript comprehensive-check $script:TestSpecs $script:ContextFile (Join-Path $Global:FixturesDir "constitution.md")
        $json = $result | ConvertFrom-Json
        $json.tdd_determination | Should -Be "mandatory"
    }
}
