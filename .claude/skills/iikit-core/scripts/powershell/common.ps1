#!/usr/bin/env pwsh
# Common PowerShell functions analogous to common.sh

function Get-RepoRoot {
    try {
        $result = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    } catch {
        # Git command failed
    }

    # Fall back to script location for non-git repos
    return (Resolve-Path (Join-Path $PSScriptRoot "../../../../..")).Path
}

function Get-CurrentBranch {
    # First check if SPECIFY_FEATURE environment variable is set
    if ($env:SPECIFY_FEATURE) {
        return $env:SPECIFY_FEATURE
    }

    # Then check git if available
    try {
        $result = git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    } catch {
        # Git command failed
    }

    # For non-git repos, try to find the latest feature directory
    $repoRoot = Get-RepoRoot
    $specsDir = Join-Path $repoRoot "specs"

    if (Test-Path $specsDir) {
        $latestFeature = ""
        $highest = 0

        Get-ChildItem -Path $specsDir -Directory | ForEach-Object {
            if ($_.Name -match '^(\d{3})-') {
                $num = [int]$matches[1]
                if ($num -gt $highest) {
                    $highest = $num
                    $latestFeature = $_.Name
                }
            }
        }

        if ($latestFeature) {
            return $latestFeature
        }
    }

    # Final fallback
    return "main"
}

function Test-HasGit {
    try {
        git rev-parse --show-toplevel 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Test-FeatureBranch {
    param(
        [string]$Branch,
        [bool]$HasGit = $true
    )

    # For non-git repos, we can't enforce branch naming but still provide output
    if (-not $HasGit) {
        Write-Warning "[specify] Warning: Git repository not detected; skipped branch validation"
        return $true
    }

    # Accept if branch matches NNN- pattern (standard feature branch)
    if ($Branch -match '^[0-9]{3}-') {
        return $true
    }

    # Accept if SPECIFY_FEATURE env var is set (explicit feature context, e.g., -SkipBranch)
    if ($env:SPECIFY_FEATURE) {
        Write-Warning "[specify] Using feature context from SPECIFY_FEATURE: $env:SPECIFY_FEATURE"
        return $true
    }

    # Check if there are feature directories we can use
    $repoRoot = Get-RepoRoot
    $specsDir = Join-Path $repoRoot 'specs'
    $featureDirs = @()

    if (Test-Path $specsDir) {
        $featureDirs = Get-ChildItem -Path $specsDir -Directory | Where-Object { $_.Name -match '^[0-9]{3}-' }
    }

    if ($featureDirs.Count -eq 1) {
        Write-Warning "[specify] Not on feature branch, but found single feature directory: $($featureDirs[0].Name)"
        $env:SPECIFY_FEATURE = $featureDirs[0].Name
        return $true
    } elseif ($featureDirs.Count -gt 1) {
        Write-Output "WARNING: Not on a feature branch and multiple feature directories exist."
        Write-Output "Current branch: $Branch"
        Write-Output "Set SPECIFY_FEATURE=<feature-name> to specify which feature to use."
        Write-Output "Or run: /iikit-01-specify to create a new feature."
        return $false
    }

    Write-Output "ERROR: Not on a feature branch. Current branch: $Branch"
    Write-Output "Run: /iikit-01-specify <feature description>"
    return $false
}

function Get-FeatureDir {
    param([string]$RepoRoot, [string]$Branch)
    Join-Path $RepoRoot "specs/$Branch"
}

# Find feature directory by numeric prefix instead of exact branch match
# This allows multiple branches to work on the same spec (e.g., 004-fix-bug, 004-add-feature)
function Find-FeatureDirByPrefix {
    param(
        [string]$RepoRoot,
        [string]$BranchName
    )

    $specsDir = Join-Path $RepoRoot "specs"

    # Extract numeric prefix from branch (e.g., "004" from "004-whatever")
    if ($BranchName -notmatch '^(\d{3})-') {
        # If branch doesn't have numeric prefix, fall back to exact match
        return Join-Path $specsDir $BranchName
    }

    $prefix = $Matches[1]

    # Search for directories in specs/ that start with this prefix
    $matches = @()
    if (Test-Path $specsDir) {
        $matches = Get-ChildItem -Path $specsDir -Directory | Where-Object { $_.Name -match "^$prefix-" }
    }

    # Handle results
    if ($matches.Count -eq 0) {
        # No match found - return the branch name path (will fail later with clear error)
        return Join-Path $specsDir $BranchName
    }
    elseif ($matches.Count -eq 1) {
        # Exactly one match - perfect!
        return Join-Path $specsDir $matches[0].Name
    }
    else {
        # Multiple matches - this shouldn't happen with proper naming convention
        Write-Error "Multiple spec directories found with prefix '$prefix': $($matches.Name -join ', ')"
        Write-Error "Please ensure only one spec directory exists per numeric prefix."
        return Join-Path $specsDir $BranchName  # Return something to avoid breaking the script
    }
}

function Get-FeaturePathsEnv {
    $repoRoot = Get-RepoRoot
    $currentBranch = Get-CurrentBranch
    $hasGit = Test-HasGit
    # Use prefix-based lookup to support multiple branches per spec
    $featureDir = Find-FeatureDirByPrefix -RepoRoot $repoRoot -BranchName $currentBranch

    [PSCustomObject]@{
        REPO_ROOT     = $repoRoot
        CURRENT_BRANCH = $currentBranch
        HAS_GIT       = $hasGit
        FEATURE_DIR   = $featureDir
        FEATURE_SPEC  = Join-Path $featureDir 'spec.md'
        IMPL_PLAN     = Join-Path $featureDir 'plan.md'
        TASKS         = Join-Path $featureDir 'tasks.md'
        RESEARCH      = Join-Path $featureDir 'research.md'
        DATA_MODEL    = Join-Path $featureDir 'data-model.md'
        QUICKSTART    = Join-Path $featureDir 'quickstart.md'
        CONTRACTS_DIR = Join-Path $featureDir 'contracts'
    }
}

function Test-FileExists {
    param([string]$Path, [string]$Description)
    if (Test-Path -Path $Path -PathType Leaf) {
        Write-Output "  [x] $Description"
        return $true
    } else {
        Write-Output "  [ ] $Description"
        return $false
    }
}

function Test-DirHasFiles {
    param([string]$Path, [string]$Description)
    if ((Test-Path -Path $Path -PathType Container) -and (Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1)) {
        Write-Output "  [x] $Description"
        return $true
    } else {
        Write-Output "  [ ] $Description"
        return $false
    }
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

function Test-Constitution {
    param([string]$RepoRoot)

    $constitution = Join-Path $RepoRoot 'CONSTITUTION.md'

    if (-not (Test-Path $constitution)) {
        Write-Error "Constitution not found at $constitution"
        Write-Host "Run /iikit-00-constitution first to define project principles."
        return $false
    }

    $content = Get-Content -Path $constitution -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch '## .*Principles|# .*Constitution') {
        Write-Warning "Constitution may be incomplete - missing principles section"
    }

    return $true
}

function Test-Spec {
    param([string]$SpecFile)

    if (-not (Test-Path $SpecFile)) {
        Write-Error "spec.md not found at $SpecFile"
        Write-Host "Run /iikit-01-specify first to create the feature specification."
        return $false
    }

    $content = Get-Content -Path $SpecFile -Raw -ErrorAction SilentlyContinue
    $errors = 0

    if ($content -notmatch '## Requirements|## Functional Requirements|### Functional Requirements') {
        Write-Error "spec.md missing 'Requirements' section"
        $errors++
    }

    if ($content -notmatch '## Success Criteria') {
        Write-Error "spec.md missing 'Success Criteria' section"
        $errors++
    }

    if ($content -notmatch '## User Scenarios|### User Story') {
        Write-Error "spec.md missing 'User Scenarios' or 'User Story' section"
        $errors++
    }

    if ($content -match '\[NEEDS CLARIFICATION') {
        $count = ([regex]::Matches($content, '\[NEEDS CLARIFICATION')).Count
        Write-Warning "spec.md has $count unresolved [NEEDS CLARIFICATION] markers"
        Write-Host "Consider running /iikit-02-clarify to resolve them."
    }

    return ($errors -eq 0)
}

function Test-Plan {
    param([string]$PlanFile)

    if (-not (Test-Path $PlanFile)) {
        Write-Error "plan.md not found at $PlanFile"
        Write-Host "Run /iikit-03-plan first to create the implementation plan."
        return $false
    }

    $content = Get-Content -Path $PlanFile -Raw -ErrorAction SilentlyContinue

    if ($content -notmatch '## Technical Context|\*\*Language/Version\*\*') {
        Write-Warning "plan.md may be incomplete - missing Technical Context"
    }

    if ($content -match 'NEEDS CLARIFICATION') {
        $count = ([regex]::Matches($content, 'NEEDS CLARIFICATION')).Count
        Write-Warning "plan.md has $count unresolved NEEDS CLARIFICATION items"
    }

    return $true
}

function Test-Tasks {
    param([string]$TasksFile)

    if (-not (Test-Path $TasksFile)) {
        Write-Error "tasks.md not found at $TasksFile"
        Write-Host "Run /iikit-06-tasks first to create the task list."
        return $false
    }

    $content = Get-Content -Path $TasksFile -Raw -ErrorAction SilentlyContinue

    if ($content -notmatch '- \[ \]|- \[x\]|- \[X\]') {
        Write-Warning "tasks.md appears to have no task items"
    }

    return $true
}

function Get-SpecQualityScore {
    param([string]$SpecFile)

    if (-not (Test-Path $SpecFile)) { return 0 }

    $content = Get-Content -Path $SpecFile -Raw -ErrorAction SilentlyContinue
    $score = 0

    # +2 for having requirements section
    if ($content -match '## Requirements|### Functional Requirements') { $score += 2 }

    # +2 for having success criteria
    if ($content -match '## Success Criteria') { $score += 2 }

    # +2 for having user scenarios
    if ($content -match '## User Scenarios|### User Story') { $score += 2 }

    # +1 for having at least 3 requirements
    $reqCount = ([regex]::Matches($content, '- \*\*FR-|- FR-')).Count
    if ($reqCount -ge 3) { $score += 1 }

    # +1 for having at least 3 success criteria
    $scCount = ([regex]::Matches($content, '- \*\*SC-|- SC-')).Count
    if ($scCount -ge 3) { $score += 1 }

    # +1 for no NEEDS CLARIFICATION markers
    if ($content -notmatch '\[NEEDS CLARIFICATION') { $score += 1 }

    # +1 for having edge cases section
    if ($content -match '### Edge Cases|## Edge Cases') { $score += 1 }

    return $score
}
