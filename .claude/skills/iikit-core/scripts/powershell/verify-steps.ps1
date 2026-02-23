#!/usr/bin/env pwsh
# Verify BDD step coverage by detecting undefined/pending steps via framework dry-run
# Usage: verify-steps.ps1 [--json] <features-dir> <plan-file>

param(
    [switch]$json,

    [Parameter(Position = 0)]
    [string]$Arg1,

    [Parameter(Position = 1)]
    [string]$Arg2,

    [Parameter(Position = 2)]
    [string]$Arg3
)

$ErrorActionPreference = "Stop"

# Parse arguments: handle --json switch or positional --json string
$JsonMode = $false
$FeaturesDir = ""
$PlanFile = ""

if ($json) {
    $JsonMode = $true
    $FeaturesDir = $Arg1
    $PlanFile = $Arg2
} elseif ($Arg1 -eq "--json") {
    $JsonMode = $true
    $FeaturesDir = $Arg2
    $PlanFile = $Arg3
} else {
    $FeaturesDir = $Arg1
    $PlanFile = $Arg2
}

# =============================================================================
# FRAMEWORK DETECTION
# =============================================================================

function Get-BddFramework {
    param(
        [string]$PlanFile,
        [string]$FeaturesDir
    )

    $framework = ""

    # Parse plan.md Technical Context for language/framework keywords
    if (Test-Path $PlanFile) {
        $planContent = Get-Content $PlanFile -Raw

        # Python + pytest-bdd
        if ($planContent -match "(?i)pytest-bdd|pytest\.bdd") {
            $framework = "pytest-bdd"
        }
        # Python + behave
        elseif ($planContent -match "(?i)behave") {
            $framework = "behave"
        }
        # JavaScript/TypeScript + Cucumber
        elseif ($planContent -match "(?i)@cucumber/cucumber|cucumber-js|cucumberjs") {
            $framework = "cucumber-js"
        }
        # Go + godog
        elseif ($planContent -match "(?i)godog") {
            $framework = "godog"
        }
        # Java + Maven + Cucumber
        elseif ($planContent -match "(?i)cucumber" -and $planContent -match "(?i)maven|mvn") {
            $framework = "cucumber-jvm-maven"
        }
        # Java + Gradle + Cucumber
        elseif ($planContent -match "(?i)cucumber" -and $planContent -match "(?i)gradle") {
            $framework = "cucumber-jvm-gradle"
        }
        # Rust + cucumber-rs
        elseif ($planContent -match "(?i)cucumber-rs|cucumber.*rust") {
            $framework = "cucumber-rs"
        }
        # C# + Reqnroll
        elseif ($planContent -match "(?i)reqnroll") {
            $framework = "reqnroll"
        }
        # Fallback: detect language from plan.md and infer default BDD framework
        elseif ($planContent -match "(?i)python|pytest") {
            $framework = "pytest-bdd"
        }
        elseif ($planContent -match "(?i)typescript|javascript|node|npm|npx") {
            $framework = "cucumber-js"
        }
        elseif ($planContent -match "(?i)\bgo\b|golang") {
            $framework = "godog"
        }
        elseif ($planContent -match "(?i)\brust\b|cargo") {
            $framework = "cucumber-rs"
        }
        elseif ($planContent -match "(?i)c#|csharp|dotnet|\.net") {
            $framework = "reqnroll"
        }
        elseif ($planContent -match "(?i)java\b") {
            $framework = "cucumber-jvm-maven"
        }
    }

    # Fall back to file extension heuristics if plan.md didn't resolve
    if ([string]::IsNullOrEmpty($framework) -and (Test-Path $FeaturesDir -PathType Container)) {
        $parentDir = Split-Path $FeaturesDir -Parent

        if (Get-ChildItem "$parentDir" -Recurse -Filter "*.py" -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1) {
            $framework = "pytest-bdd"
        }
        elseif (Get-ChildItem "$parentDir" -Recurse -Include "*.ts","*.js" -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1) {
            $framework = "cucumber-js"
        }
        elseif (Get-ChildItem "$parentDir" -Recurse -Filter "*.go" -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1) {
            $framework = "godog"
        }
        elseif (Get-ChildItem "$parentDir" -Recurse -Filter "*.rs" -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1) {
            $framework = "cucumber-rs"
        }
        elseif (Get-ChildItem "$parentDir" -Recurse -Filter "*.cs" -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1) {
            $framework = "reqnroll"
        }
        elseif (Get-ChildItem "$parentDir" -Recurse -Filter "*.java" -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1) {
            $framework = "cucumber-jvm-maven"
        }
    }

    return $framework
}

# Get the dry-run command for a given framework
function Get-DryRunCommand {
    param(
        [string]$Framework,
        [string]$FeaturesDir
    )

    switch ($Framework) {
        "pytest-bdd"          { return "pytest --collect-only tests/" }
        "behave"              { return "behave --dry-run --strict" }
        "cucumber-js"         { return "npx cucumber-js --dry-run --strict" }
        "godog"               { return "godog --strict --no-colors --dry-run" }
        "cucumber-jvm-maven"  { return 'mvn test -Dcucumber.options="--dry-run --strict"' }
        "cucumber-jvm-gradle" { return 'gradle test -Dcucumber.options="--dry-run --strict"' }
        "cucumber-rs"         { return "cargo test" }
        "reqnroll"            { return 'dotnet test -e "REQNROLL_DRY_RUN=true"' }
        default               { return "" }
    }
}

# =============================================================================
# STEP COUNTING
# =============================================================================

function Get-FeatureStepCount {
    param([string]$FeaturesDir)

    $count = 0
    if (Test-Path $FeaturesDir -PathType Container) {
        $files = Get-ChildItem "$FeaturesDir/*.feature" -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $lines = Get-Content $file.FullName | Where-Object { $_ -match '^\s*(Given|When|Then|And|But) ' }
            if ($lines) {
                $count += @($lines).Count
            }
        }
    }
    return $count
}

# =============================================================================
# DRY-RUN EXECUTION AND PARSING
# =============================================================================

function Invoke-DryRun {
    param(
        [string]$Framework,
        [string]$FeaturesDir
    )

    $dryRunCmd = Get-DryRunCommand -Framework $Framework -FeaturesDir $FeaturesDir
    if ([string]::IsNullOrEmpty($dryRunCmd)) {
        return ""
    }

    try {
        $output = Invoke-Expression "$dryRunCmd 2>&1" -ErrorAction SilentlyContinue
        return ($output -join "`n")
    } catch {
        return $_.Exception.Message
    }
}

function Get-ParsedResults {
    param(
        [string]$Framework,
        [string]$Output,
        [string]$FeaturesDir
    )

    $totalSteps = Get-FeatureStepCount -FeaturesDir $FeaturesDir
    $undefinedSteps = 0
    $pendingSteps = 0
    $details = @()

    switch ($Framework) {
        "pytest-bdd" {
            $undefinedMatches = [regex]::Matches($Output, "StepDefNotFound|ERRORS|no tests ran")
            $undefinedSteps = $undefinedMatches.Count
        }
        "behave" {
            $undefinedMatches = [regex]::Matches($Output, "(?i)undefined")
            $pendingMatches = [regex]::Matches($Output, "(?i)pending|skipped")
            $undefinedSteps = $undefinedMatches.Count
            $pendingSteps = $pendingMatches.Count
        }
        "cucumber-js" {
            $undefinedMatches = [regex]::Matches($Output, "Undefined")
            $pendingMatches = [regex]::Matches($Output, "Pending")
            $undefinedSteps = $undefinedMatches.Count
            $pendingSteps = $pendingMatches.Count
        }
        "godog" {
            $undefinedMatches = [regex]::Matches($Output, "(?i)undefined")
            $pendingMatches = [regex]::Matches($Output, "(?i)pending")
            $undefinedSteps = $undefinedMatches.Count
            $pendingSteps = $pendingMatches.Count
        }
        { $_ -in "cucumber-jvm-maven", "cucumber-jvm-gradle" } {
            $undefinedMatches = [regex]::Matches($Output, "Undefined")
            $pendingMatches = [regex]::Matches($Output, "Pending")
            $undefinedSteps = $undefinedMatches.Count
            $pendingSteps = $pendingMatches.Count
        }
        "cucumber-rs" {
            $undefinedMatches = [regex]::Matches($Output, "(?i)skipped|undefined")
            $undefinedSteps = $undefinedMatches.Count
        }
        "reqnroll" {
            $undefinedMatches = [regex]::Matches($Output, "(?i)Binding|StepDefinitionMissing|undefined")
            $undefinedSteps = $undefinedMatches.Count
        }
    }

    $matchedSteps = $totalSteps - $undefinedSteps - $pendingSteps
    if ($matchedSteps -lt 0) {
        $matchedSteps = 0
    }

    $status = "PASS"
    if ($undefinedSteps -gt 0 -or $pendingSteps -gt 0) {
        $status = "BLOCKED"
    }

    return @{
        status          = $status
        framework       = $Framework
        total_steps     = $totalSteps
        matched_steps   = $matchedSteps
        undefined_steps = $undefinedSteps
        pending_steps   = $pendingSteps
        details         = $details
    }
}

# =============================================================================
# OUTPUT HELPERS
# =============================================================================

function Write-DegradedOutput {
    param(
        [bool]$JsonMode,
        [string]$Message = "No BDD framework detected for tech stack. Verification chain is not integral.",
        [string]$Framework = $null
    )

    if ($JsonMode) {
        $result = @{
            status          = "DEGRADED"
            framework       = $Framework
            message         = $Message
            total_steps     = 0
            matched_steps   = 0
            undefined_steps = 0
            pending_steps   = 0
            details         = @()
        }
        Write-Output ($result | ConvertTo-Json -Compress)
    } else {
        Write-Output "[verify-steps] DEGRADED: $Message"
    }
}

function Write-ResultOutput {
    param(
        [bool]$JsonMode,
        [hashtable]$Result
    )

    if ($JsonMode) {
        Write-Output ($Result | ConvertTo-Json -Compress)
    } else {
        Write-Output "[verify-steps] Status: $($Result.status)"
        Write-Output "[verify-steps] Framework: $($Result.framework)"
        Write-Output "[verify-steps] Steps: $($Result.matched_steps)/$($Result.total_steps) matched, $($Result.undefined_steps) undefined, $($Result.pending_steps) pending"

        if ($Result.status -eq "BLOCKED") {
            Write-Output "[verify-steps] WARNING: Undefined or pending steps detected. Step definitions are incomplete."
        }
    }
}

# =============================================================================
# MAIN
# =============================================================================

# Validate arguments
if ([string]::IsNullOrEmpty($FeaturesDir) -or [string]::IsNullOrEmpty($PlanFile)) {
    Write-Error "Usage: verify-steps.ps1 [--json] <features-dir> <plan-file>"
    exit 1
}

# Validate features directory
if (-not (Test-Path $FeaturesDir -PathType Container)) {
    Write-DegradedOutput -JsonMode $JsonMode -Message "Features directory not found: $FeaturesDir"
    exit 0
}

# Check for .feature files
$featureFiles = Get-ChildItem "$FeaturesDir/*.feature" -ErrorAction SilentlyContinue
if (-not $featureFiles -or @($featureFiles).Count -eq 0) {
    Write-DegradedOutput -JsonMode $JsonMode -Message "No .feature files found in $FeaturesDir"
    exit 0
}

# Detect framework
$framework = Get-BddFramework -PlanFile $PlanFile -FeaturesDir $FeaturesDir

if ([string]::IsNullOrEmpty($framework)) {
    Write-DegradedOutput -JsonMode $JsonMode
    exit 0
}

# Check if dry-run command tool is available
$dryRunCmd = Get-DryRunCommand -Framework $framework -FeaturesDir $FeaturesDir
if ([string]::IsNullOrEmpty($dryRunCmd)) {
    Write-DegradedOutput -JsonMode $JsonMode
    exit 0
}

# Extract base command to check availability
$baseCmd = ($dryRunCmd -split '\s+')[0]
$cmdAvailable = $false
try {
    $cmd = Get-Command $baseCmd -ErrorAction SilentlyContinue
    $cmdAvailable = ($null -ne $cmd)
} catch {
    $cmdAvailable = $false
}

if (-not $cmdAvailable) {
    Write-DegradedOutput -JsonMode $JsonMode -Message "Framework tool not found: $baseCmd. Install it to enable step verification." -Framework $framework
    exit 0
}

# Run dry-run
$dryRunOutput = Invoke-DryRun -Framework $framework -FeaturesDir $FeaturesDir

# Parse results
$result = Get-ParsedResults -Framework $framework -Output $dryRunOutput -FeaturesDir $FeaturesDir

# Output
Write-ResultOutput -JsonMode $JsonMode -Result $result

# Exit code: 0 for PASS/DEGRADED, 1 for BLOCKED
if ($result.status -eq "BLOCKED") {
    exit 1
}
exit 0
