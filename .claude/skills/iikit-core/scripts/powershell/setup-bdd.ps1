# BDD Framework Scaffolding
# Auto-detects BDD framework from plan.md and scaffolds directory structure + dependencies
# Usage: setup-bdd.ps1 [--json] <features-dir> <plan-file>

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

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

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

if ([string]::IsNullOrEmpty($FeaturesDir) -or [string]::IsNullOrEmpty($PlanFile)) {
    Write-Error "Usage: setup-bdd.ps1 [--json] <features-dir> <plan-file>"
    exit 1
}

# =============================================================================
# FRAMEWORK DETECTION
# =============================================================================

function Detect-Framework {
    param([string]$PlanFile)

    if (-not (Test-Path $PlanFile)) {
        return $null
    }

    $content = Get-Content $PlanFile -Raw

    # Python + pytest-bdd
    if ($content -match "(?i)pytest-bdd") {
        return @{ Framework = "pytest-bdd"; Language = "python" }
    }

    # Python + behave
    if ($content -match "(?i)behave") {
        return @{ Framework = "behave"; Language = "python" }
    }

    # JavaScript/TypeScript + Cucumber
    if ($content -match "(?i)@cucumber/cucumber|cucumber-js|cucumber\.js") {
        return @{ Framework = "@cucumber/cucumber"; Language = "javascript" }
    }

    # Go + godog
    if ($content -match "(?i)godog") {
        return @{ Framework = "godog"; Language = "go" }
    }

    # Java + Maven + Cucumber-JVM
    if ($content -match "(?i)cucumber" -and $content -match "(?i)maven|pom\.xml") {
        return @{ Framework = "cucumber-jvm-maven"; Language = "java" }
    }

    # Java + Gradle + Cucumber-JVM
    if ($content -match "(?i)cucumber" -and $content -match "(?i)gradle") {
        return @{ Framework = "cucumber-jvm-gradle"; Language = "java" }
    }

    # Rust + cucumber-rs
    if ($content -match "(?i)cucumber-rs|cucumber.*rust|rust.*cucumber") {
        return @{ Framework = "cucumber-rs"; Language = "rust" }
    }

    # C# + Reqnroll
    if ($content -match "(?i)reqnroll") {
        return @{ Framework = "reqnroll"; Language = "csharp" }
    }

    # Fallback: detect language and infer framework
    if ($content -match "(?i)python|pytest") {
        return @{ Framework = "pytest-bdd"; Language = "python" }
    }

    if ($content -match "(?i)javascript|typescript|node\.js|jest|vitest") {
        return @{ Framework = "@cucumber/cucumber"; Language = "javascript" }
    }

    if ($content -match "(?i)golang|go test|go 1\.|Language/Version.*Go") {
        return @{ Framework = "godog"; Language = "go" }
    }

    if ($content -match "(?i)java\b.*(jdk|jre|spring|maven|gradle)") {
        if ($content -match "(?i)gradle") {
            return @{ Framework = "cucumber-jvm-gradle"; Language = "java" }
        } else {
            return @{ Framework = "cucumber-jvm-maven"; Language = "java" }
        }
    }

    if ($content -match "(?i)rust|cargo") {
        return @{ Framework = "cucumber-rs"; Language = "rust" }
    }

    if ($content -match "(?i)c#|csharp|\.net|dotnet") {
        return @{ Framework = "reqnroll"; Language = "csharp" }
    }

    return $null
}

# =============================================================================
# EXISTING SCAFFOLDING CHECK
# =============================================================================

function Test-ExistingScaffolding {
    param([string]$FeaturesDir)

    $stepDefsDir = Join-Path (Split-Path $FeaturesDir -Parent) "step_definitions"

    return (Test-Path $FeaturesDir -PathType Container) -and (Test-Path $stepDefsDir -PathType Container)
}

# =============================================================================
# DIRECTORY CREATION
# =============================================================================

function New-BddDirectories {
    param([string]$FeaturesDir)

    $stepDefsDir = Join-Path (Split-Path $FeaturesDir -Parent) "step_definitions"
    $created = @()

    if (-not (Test-Path $FeaturesDir -PathType Container)) {
        New-Item -ItemType Directory -Path $FeaturesDir -Force | Out-Null
        $parentName = Split-Path (Split-Path $FeaturesDir -Parent) -Leaf
        $created += "$parentName/features"
    }

    if (-not (Test-Path $stepDefsDir -PathType Container)) {
        New-Item -ItemType Directory -Path $stepDefsDir -Force | Out-Null
        $parentName = Split-Path (Split-Path $FeaturesDir -Parent) -Leaf
        $created += "$parentName/step_definitions"
    }

    return $created
}

# =============================================================================
# FRAMEWORK INSTALLATION
# =============================================================================

function Install-BddFramework {
    param([string]$Framework)

    $installed = @()

    switch ($Framework) {
        "pytest-bdd" {
            if (Get-Command pip3 -ErrorAction SilentlyContinue) {
                try { pip3 install pytest-bdd 2>&1 | Out-Null; $installed += "pytest-bdd" } catch {}
            } elseif (Get-Command pip -ErrorAction SilentlyContinue) {
                try { pip install pytest-bdd 2>&1 | Out-Null; $installed += "pytest-bdd" } catch {}
            }
        }
        "behave" {
            if (Get-Command pip3 -ErrorAction SilentlyContinue) {
                try { pip3 install behave 2>&1 | Out-Null; $installed += "behave" } catch {}
            } elseif (Get-Command pip -ErrorAction SilentlyContinue) {
                try { pip install behave 2>&1 | Out-Null; $installed += "behave" } catch {}
            }
        }
        "@cucumber/cucumber" {
            if (Get-Command npm -ErrorAction SilentlyContinue) {
                try { npm install --save-dev "@cucumber/cucumber" 2>&1 | Out-Null; $installed += "@cucumber/cucumber" } catch {}
            }
        }
        "godog" {
            if (Get-Command go -ErrorAction SilentlyContinue) {
                try { go get github.com/cucumber/godog 2>&1 | Out-Null; $installed += "godog" } catch {}
            }
        }
        "cucumber-jvm-maven" {
            Write-Host "Add Cucumber-JVM dependency to pom.xml: io.cucumber:cucumber-java, io.cucumber:cucumber-junit-platform-engine" -ForegroundColor Yellow
        }
        "cucumber-jvm-gradle" {
            Write-Host "Add Cucumber-JVM dependency to build.gradle: io.cucumber:cucumber-java, io.cucumber:cucumber-junit-platform-engine" -ForegroundColor Yellow
        }
        "cucumber-rs" {
            Write-Host 'Add cucumber dependency to Cargo.toml: cucumber = { version = "0.20" }' -ForegroundColor Yellow
        }
        "reqnroll" {
            if (Get-Command dotnet -ErrorAction SilentlyContinue) {
                try { dotnet add package Reqnroll.NUnit 2>&1 | Out-Null; $installed += "Reqnroll.NUnit" } catch {}
            }
        }
    }

    return $installed
}

# =============================================================================
# JSON OUTPUT
# =============================================================================

function Write-JsonOutput {
    param(
        [string]$Status,
        [string]$Framework,
        [string]$Language,
        [string[]]$DirectoriesCreated,
        [string[]]$PackagesInstalled,
        [string]$Message
    )

    if ($Status -eq "NO_FRAMEWORK") {
        $result = @{
            status = "NO_FRAMEWORK"
            framework = $null
            language = "unknown"
            message = "No BDD framework detected for tech stack. Feature files will be generated without framework scaffolding."
        }
    } else {
        $result = @{
            status = $Status
            framework = $Framework
            language = $Language
            directories_created = @($DirectoriesCreated)
            packages_installed = @($PackagesInstalled)
            config_files_created = @()
        }
    }

    return ($result | ConvertTo-Json -Compress)
}

function Write-HumanOutput {
    param(
        [string]$Status,
        [string]$Framework,
        [string]$Language,
        [string[]]$DirectoriesCreated,
        [string[]]$PackagesInstalled
    )

    switch ($Status) {
        "SCAFFOLDED" {
            Write-Host "[setup-bdd] Scaffolded BDD framework: $Framework ($Language)"
            Write-Host "  Directories: $($DirectoriesCreated -join ', ')"
            Write-Host "  Packages: $($PackagesInstalled -join ', ')"
        }
        "ALREADY_SCAFFOLDED" {
            Write-Host "[setup-bdd] BDD scaffolding already exists for $Framework ($Language)"
        }
        "NO_FRAMEWORK" {
            Write-Host "[setup-bdd] WARNING: No BDD framework detected for tech stack."
            Write-Host "  Feature files will be generated without framework scaffolding."
            Write-Host "  Directories created: $($DirectoriesCreated -join ', ')"
        }
    }
}

# =============================================================================
# MAIN
# =============================================================================

# Detect framework
$detection = Detect-Framework -PlanFile $PlanFile

if ($null -eq $detection) {
    # NO_FRAMEWORK fallback: create directories but no framework install
    $dirsCreated = New-BddDirectories -FeaturesDir $FeaturesDir

    if ($JsonMode) {
        Write-JsonOutput -Status "NO_FRAMEWORK" -Framework "" -Language "" -DirectoriesCreated @($dirsCreated) -PackagesInstalled @()
    } else {
        Write-HumanOutput -Status "NO_FRAMEWORK" -Framework "" -Language "" -DirectoriesCreated @($dirsCreated) -PackagesInstalled @()
    }
    exit 0
}

$framework = $detection.Framework
$language = $detection.Language

# Check for existing scaffolding (idempotency)
$alreadyScaffolded = Test-ExistingScaffolding -FeaturesDir $FeaturesDir

if ($alreadyScaffolded) {
    if ($JsonMode) {
        Write-JsonOutput -Status "ALREADY_SCAFFOLDED" -Framework $framework -Language $language -DirectoriesCreated @() -PackagesInstalled @()
    } else {
        Write-HumanOutput -Status "ALREADY_SCAFFOLDED" -Framework $framework -Language $language -DirectoriesCreated @() -PackagesInstalled @()
    }
    exit 0
}

# Create directories
$dirsCreated = New-BddDirectories -FeaturesDir $FeaturesDir

# Install framework
$pkgsInstalled = Install-BddFramework -Framework $framework

if ($null -eq $pkgsInstalled) {
    $pkgsInstalled = @()
}

# Output result
if ($JsonMode) {
    Write-JsonOutput -Status "SCAFFOLDED" -Framework $framework -Language $language -DirectoriesCreated @($dirsCreated) -PackagesInstalled @($pkgsInstalled)
} else {
    Write-HumanOutput -Status "SCAFFOLDED" -Framework $framework -Language $language -DirectoriesCreated @($dirsCreated) -PackagesInstalled @($pkgsInstalled)
}

exit 0
