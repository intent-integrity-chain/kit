# Tests for verify-step-quality.ps1 (T052 - BDD Verification Chain)

BeforeAll {
    Import-Module $PSScriptRoot/TestHelper.psm1 -Force
    $script:VerifyQualityScript = Join-Path $Global:ScriptsDir "verify-step-quality.ps1"
}

# =============================================================================
# Helper: create Python step definition files
# =============================================================================

function New-PythonGoodSteps {
    param([string]$Dir)

    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    }

    $content = @'
from pytest_bdd import given, when, then

@given("a registered user")
def step_registered_user(context):
    context.user = {"name": "test", "email": "test@example.com"}

@when("they enter valid credentials")
def step_enter_credentials(context):
    context.result = login(context.user)

@then("they are logged in")
def step_logged_in(context):
    assert context.result.status == "success"

@then("they see the dashboard")
def step_see_dashboard(context):
    assert "dashboard" in context.result.redirect
'@
    Set-Content -Path (Join-Path $Dir "test_steps.py") -Value $content -Encoding utf8
}

function New-PythonBadSteps {
    param([string]$Dir)

    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    }

    $content = @'
from pytest_bdd import given, when, then

@given("a user exists")
def step_user_exists():
    pass

@when("the user performs an action")
def step_action():
    """Not implemented yet."""

@then("the result is correct")
def step_result_correct():
    assert True

@then("everything works")
def step_everything():
    assert 1

@then("the data is saved")
def step_data_saved(context):
    print("data saved")
'@
    Set-Content -Path (Join-Path $Dir "test_bad_steps.py") -Value $content -Encoding utf8
}

# =============================================================================
# Helper: create JavaScript step definition files
# =============================================================================

function New-JavaScriptGoodSteps {
    param([string]$Dir)

    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    }

    $content = @'
const { Given, When, Then } = require('@cucumber/cucumber');
const assert = require('assert');

Given('a registered user', function () {
    this.user = { name: 'test', email: 'test@example.com' };
});

When('they enter valid credentials', function () {
    this.result = login(this.user);
});

Then('they are logged in', function () {
    assert.strictEqual(this.result.status, 'success');
});

Then('they see the dashboard', function () {
    assert.ok(this.result.redirect.includes('dashboard'));
});
'@
    Set-Content -Path (Join-Path $Dir "steps.js") -Value $content -Encoding utf8
}

function New-JavaScriptBadSteps {
    param([string]$Dir)

    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    }

    $content = @'
const { Given, When, Then } = require('@cucumber/cucumber');

Given('a user exists', function () {
});

When('the user clicks a button', function () {
    // TODO
});

Then('the result is correct', function () {
    assert.ok(true);
});

Then('the data is saved', function () {
    console.log('saved');
});
'@
    Set-Content -Path (Join-Path $Dir "steps.js") -Value $content -Encoding utf8
}

# =============================================================================
# Argument validation
# =============================================================================

Describe "verify-step-quality.ps1 - Argument validation" {
    It "fails when no arguments provided" {
        { & $script:VerifyQualityScript 2>&1 } | Should -Throw
    }

    It "fails when only directory provided (missing language)" {
        { & $script:VerifyQualityScript --json "/tmp/somedir" 2>&1 } | Should -Throw
    }

    It "returns ERROR for nonexistent directory in JSON mode" {
        $result = & $script:VerifyQualityScript --json "/nonexistent" "python" 2>&1 | Out-String
        $result | Should -Match '"status":\s*"ERROR"'
    }

    It "fails for nonexistent directory in text mode" {
        { & $script:VerifyQualityScript "/nonexistent" "python" 2>&1 } | Should -Throw
    }
}

# =============================================================================
# Python AST analysis - PASS cases
# =============================================================================

Describe "verify-step-quality.ps1 - Python PASS cases" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns PASS for good Python step definitions" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonGoodSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "python" 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.status | Should -Be "PASS"
        $parsed.language | Should -Be "python"
        $parsed.parser | Should -Be "ast"
    }

    It "counts correct number of good Python steps" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonGoodSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "python" 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.total_steps | Should -Be 4
        $parsed.quality_pass | Should -Be 4
        $parsed.quality_fail | Should -Be 0
    }

    It "returns PASS for empty directory (no steps)" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "empty_steps"
        New-Item -ItemType Directory -Path $stepsDir -Force | Out-Null

        $result = & $script:VerifyQualityScript --json $stepsDir "python" 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.status | Should -Be "PASS"
        $parsed.total_steps | Should -Be 0
    }
}

# =============================================================================
# Python AST analysis - BLOCKED cases
# =============================================================================

Describe "verify-step-quality.ps1 - Python BLOCKED cases" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns BLOCKED for bad Python step definitions" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonBadSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "python" 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.status | Should -Be "BLOCKED"
    }

    It "detects EMPTY_BODY issue in Python steps" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonBadSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "python" 2>&1 | Out-String
        $result | Should -Match '"issue":\s*"EMPTY_BODY"'
    }

    It "detects TAUTOLOGY issue in Python steps" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonBadSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "python" 2>&1 | Out-String
        $result | Should -Match '"issue":\s*"TAUTOLOGY"'
    }

    It "detects NO_ASSERTION issue in Python then steps" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonBadSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "python" 2>&1 | Out-String
        $result | Should -Match '"issue":\s*"NO_ASSERTION"'
    }

    It "includes file and line in detail items" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonBadSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "python" 2>&1 | Out-String
        $result | Should -Match '"file":'
        $result | Should -Match '"line":'
    }
}

# =============================================================================
# JavaScript analysis
# =============================================================================

Describe "verify-step-quality.ps1 - JavaScript analysis" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "returns PASS for good JavaScript step definitions" -Skip:($null -eq (Get-Command node -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-JavaScriptGoodSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "javascript" 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.status | Should -Be "PASS"
        $parsed.language | Should -Be "javascript"
        $parsed.parser | Should -Be "node"
    }

    It "returns BLOCKED for bad JavaScript step definitions" -Skip:($null -eq (Get-Command node -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-JavaScriptBadSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "javascript" 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.status | Should -Be "BLOCKED"
    }

    It "detects EMPTY_BODY in JavaScript steps" -Skip:($null -eq (Get-Command node -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-JavaScriptBadSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "javascript" 2>&1 | Out-String
        $result | Should -Match '"issue":\s*"EMPTY_BODY"'
    }
}

# =============================================================================
# Language aliases
# =============================================================================

Describe "verify-step-quality.ps1 - Language aliases" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "accepts 'py' as alias for python" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonGoodSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "py" 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.language | Should -Be "python"
    }

    It "accepts 'js' as alias for javascript" -Skip:($null -eq (Get-Command node -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-JavaScriptGoodSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "js" 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.language | Should -Be "javascript"
    }

    It "accepts 'ts' as alias for typescript" {
        $stepsDir = Join-Path $script:TestDir "ts_steps"
        New-Item -ItemType Directory -Path $stepsDir -Force | Out-Null

        $result = & $script:VerifyQualityScript --json $stepsDir "ts" 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.language | Should -Be "typescript"
    }
}

# =============================================================================
# Regex fallback (DEGRADED_ANALYSIS)
# =============================================================================

Describe "verify-step-quality.ps1 - Regex fallback" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "uses regex fallback for Java language" {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-Item -ItemType Directory -Path $stepsDir -Force | Out-Null

        $javaContent = @'
import io.cucumber.java.en.Given;
import io.cucumber.java.en.When;
import io.cucumber.java.en.Then;

public class StepDefs {
    @Given("a user exists")
    public void aUserExists() {
        // setup user
    }

    @When("the user logs in")
    public void theUserLogsIn() {
        // perform login
    }

    @Then("the user is authenticated")
    public void theUserIsAuthenticated() {
        assertTrue(user.isAuthenticated());
    }
}
'@
        Set-Content -Path (Join-Path $stepsDir "StepDefs.java") -Value $javaContent -Encoding utf8

        $result = & $script:VerifyQualityScript --json $stepsDir "java" 2>&1 | Out-String
        $parsed = $result.Trim() | ConvertFrom-Json
        $parsed.parser | Should -Be "regex"
        $parsed.total_steps | Should -BeGreaterOrEqual 3
    }

    It "includes DEGRADED_ANALYSIS in parser_note for unsupported languages" {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-Item -ItemType Directory -Path $stepsDir -Force | Out-Null
        Set-Content -Path (Join-Path $stepsDir "steps.rb") -Value "# ruby steps" -Encoding utf8

        $result = & $script:VerifyQualityScript --json $stepsDir "ruby" 2>&1 | Out-String
        $result | Should -Match "DEGRADED_ANALYSIS"
    }
}

# =============================================================================
# JSON output schema validation
# =============================================================================

Describe "verify-step-quality.ps1 - JSON output schema" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "JSON output has all required fields for PASS" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonGoodSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript --json $stepsDir "python" 2>&1 | Out-String
        $result | Should -Match '"status"'
        $result | Should -Match '"language"'
        $result | Should -Match '"parser"'
        $result | Should -Match '"total_steps"'
        $result | Should -Match '"quality_pass"'
        $result | Should -Match '"quality_fail"'
        $result | Should -Match '"details"'
    }

    It "JSON output is valid JSON" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonGoodSteps -Dir $stepsDir

        $output = & $script:VerifyQualityScript --json $stepsDir "python" 2>&1 | Out-String
        { $output.Trim() | ConvertFrom-Json } | Should -Not -Throw
    }
}

# =============================================================================
# Exit code behavior
# =============================================================================

Describe "verify-step-quality.ps1 - Exit codes" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "exit code 0 for PASS" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonGoodSteps -Dir $stepsDir

        & $script:VerifyQualityScript --json $stepsDir "python" 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It "exit code non-zero for BLOCKED" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonBadSteps -Dir $stepsDir

        & $script:VerifyQualityScript --json $stepsDir "python" 2>&1 | Out-Null
        $LASTEXITCODE | Should -Not -Be 0
    }
}

# =============================================================================
# Human-readable output mode
# =============================================================================

Describe "verify-step-quality.ps1 - Human-readable output" {
    BeforeEach {
        $script:TestDir = New-TestDirectory
    }

    AfterEach {
        Remove-TestDirectory -TestDir $script:TestDir
    }

    It "shows Step Quality Analysis header in text mode" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonGoodSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript $stepsDir "python" 2>&1 | Out-String
        $result | Should -Match "Step Quality Analysis"
    }

    It "shows language and parser in text mode" -Skip:($null -eq (Get-Command python3 -ErrorAction SilentlyContinue)) {
        $stepsDir = Join-Path $script:TestDir "steps"
        New-PythonGoodSteps -Dir $stepsDir

        $result = & $script:VerifyQualityScript $stepsDir "python" 2>&1 | Out-String
        $result | Should -Match "Language:\s+python"
        $result | Should -Match "Parser:\s+ast"
    }
}
