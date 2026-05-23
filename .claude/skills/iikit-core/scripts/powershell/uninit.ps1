#!/usr/bin/env pwsh
# Remove intent-integrity-kit scaffolding from a project so `tessl uninstall`
# does not leave broken hooks, orphaned `.specify/`, or stale tile artifacts behind.
# Run BEFORE `tessl uninstall tessl-labs/intent-integrity-kit`.
[CmdletBinding()]
param(
    [Alias('j')]
    [switch]$Json,
    [switch]$DryRun,
    [switch]$RemoveUserContent,
    [Alias('h')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "Usage: ./uninit.ps1 [-Json] [-DryRun] [-RemoveUserContent]"
    Write-Host ""
    Write-Host "Remove iikit scaffolding before tessl uninstall."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Json                 Output JSON"
    Write-Host "  -DryRun               Report what would change without modifying anything"
    Write-Host "  -RemoveUserContent    Also delete CONSTITUTION.md, PREMISE.md, specs/"
    exit 0
}

# Resolve the actual git repo root so a sub-directory invocation still
# operates on the top of the project (matches bash's get_repo_root behavior).
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
$repoRoot = (Resolve-Path $repoRoot).Path

# Resolve hooks directory via `git rev-parse --git-path hooks` so linked
# worktrees and submodules (where `.git` is a file pointing at the gitdir)
# find the real hooks dir — typically the main repo's `.git/hooks/` or
# `.git/modules/<name>/hooks/` for submodules.
$hooksRel = git -C $repoRoot rev-parse --git-path hooks 2>$null
if ($hooksRel) {
    if ([System.IO.Path]::IsPathRooted($hooksRel)) {
        $hooksDir = $hooksRel
    } else {
        $hooksDir = Join-Path $repoRoot $hooksRel
    }
} else {
    $hooksDir = Join-Path $repoRoot ".git/hooks"
}

$removed = New-Object System.Collections.Generic.List[string]
$userContent = New-Object System.Collections.Generic.List[string]
$errors = New-Object System.Collections.Generic.List[string]

function To-Relative([string]$abs) {
    # Strip the repoRoot prefix only when it actually matches; in worktrees /
    # submodules the hooks dir resolves outside the working tree, so keep the
    # absolute path rather than slicing arbitrary bytes off the front.
    if ($abs.StartsWith($repoRoot, [System.StringComparison]::Ordinal)) {
        return $abs.Substring($repoRoot.Length).TrimStart([char]'/', [char]'\')
    }
    return $abs
}

function Remove-Path([string]$path) {
    if (-not (Test-Path $path)) { return }
    $rel = To-Relative $path
    if ($DryRun) {
        $removed.Add($rel) | Out-Null
        return
    }
    try {
        Remove-Item $path -Recurse -Force -ErrorAction Stop
        if (Test-Path $path) {
            $msg = "failed to remove $rel — check that no process is holding files inside it, then delete '$rel' manually before running ``tessl uninstall``"
            $errors.Add($msg) | Out-Null
            [Console]::Error.WriteLine("[uninit] ERROR: $msg")
            return
        }
        $removed.Add($rel) | Out-Null
    } catch [System.UnauthorizedAccessException] {
        $msg = "permission denied removing ${rel} ($($_.Exception.Message)) — re-run elevated (Run as Administrator) or grant write access on the parent directory, then re-run ``/iikit-core uninit``"
        $errors.Add($msg) | Out-Null
        [Console]::Error.WriteLine("[uninit] ERROR: $msg")
    } catch [System.IO.IOException] {
        $msg = "I/O error removing ${rel} ($($_.Exception.Message)) — close any process or editor that has '$rel' open, then re-run ``/iikit-core uninit``"
        $errors.Add($msg) | Out-Null
        [Console]::Error.WriteLine("[uninit] ERROR: $msg")
    }
}

function Strip-ChainCall([string]$hookName) {
    $hook = Join-Path $hooksDir $hookName
    if (-not (Test-Path $hook)) { return }
    $content = Get-Content $hook -Raw -ErrorAction SilentlyContinue
    # Require BOTH the marker comment and the chain-call line — a hook that
    # merely mentions `iikit-pre-commit` in a comment must not be treated
    # as iikit-managed and rewritten.
    if ($content -cnotmatch '# IIKit assertion integrity check') { return }
    if ($content -cnotmatch "iikit-$hookName") { return }

    $rel = To-Relative $hook
    if ($DryRun) {
        $removed.Add("$rel (stripped iikit chain-call)") | Out-Null
        return
    }

    try {
        $lines = Get-Content $hook -ErrorAction Stop
        $out = New-Object System.Collections.Generic.List[string]
        $skip = 0
        foreach ($line in $lines) {
            if ($skip -eq 0 -and $line -eq "# IIKit assertion integrity check") {
                $skip = 2
                continue
            }
            if ($skip -gt 0 -and ($line -match "iikit-$hookName" -or $line -eq "")) {
                $skip--
                continue
            }
            $out.Add($line) | Out-Null
        }
        Set-Content -Path $hook -Value $out -ErrorAction Stop
        $removed.Add("$rel (stripped iikit chain-call)") | Out-Null
    } catch [System.UnauthorizedAccessException] {
        $msg = "permission denied rewriting ${rel} ($($_.Exception.Message)) — re-run elevated or grant write access on the .git/hooks directory, then re-run ``/iikit-core uninit``"
        $errors.Add($msg) | Out-Null
        [Console]::Error.WriteLine("[uninit] ERROR: $msg")
    } catch [System.IO.IOException] {
        $msg = "I/O error rewriting ${rel} ($($_.Exception.Message)) — close any editor with '$rel' open and check disk space, then re-run ``/iikit-core uninit``"
        $errors.Add($msg) | Out-Null
        [Console]::Error.WriteLine("[uninit] ERROR: $msg")
    }
}

function Handle-Hook([string]$hookName, [string]$marker) {
    $hook = Join-Path $hooksDir $hookName
    # Case-sensitive match — the marker is an uppercase tag (`IIKIT-PRE-COMMIT`)
    # the iikit hook installer writes into its own files. The chain-call line a
    # non-iikit hook contains uses the lowercase script name (`iikit-pre-commit`)
    # and must not be treated as marker presence, otherwise the user's hook gets
    # deleted instead of having the chain-call stripped.
    if ((Test-Path $hook) -and ((Get-Content $hook -Raw -ErrorAction SilentlyContinue) -cmatch $marker)) {
        Remove-Path $hook
    } else {
        Strip-ChainCall $hookName
    }
    Remove-Path (Join-Path $hooksDir "iikit-$hookName")
}

if (Test-Path $hooksDir) {
    Handle-Hook "pre-commit"  "IIKIT-PRE-COMMIT"
    Handle-Hook "post-commit" "IIKIT-POST-COMMIT"
}

# pre-commit.d/: remove our IIKIT-PRE-COMMIT-D README; report every remaining
# entry (scripts, dotfiles, subdirs, non-iikit READMEs) as user content; drop
# the dir only when no entries remain. Uses the same `$hooksDir` as the hook
# removal above to stay in lockstep — see #67 for cross-script worktree handling.
$preCommitD = Join-Path $hooksDir "pre-commit.d"
if (Test-Path $preCommitD) {
    $preCommitDReadme = Join-Path $preCommitD "README"
    $preCommitDReadmeHandled = $false
    if (Test-Path $preCommitDReadme) {
        $readmeContent = Get-Content $preCommitDReadme -Raw -ErrorAction SilentlyContinue
        if ($readmeContent -match 'IIKIT-PRE-COMMIT-D') {
            Remove-Path $preCommitDReadme
            # Only treat the README as handled when it's actually gone (or in
            # -DryRun, where it stays on disk but is logically removed). A
            # failed Remove-Path leaves the file in place and subsequent
            # emptiness detection should still see it.
            if ($DryRun -or -not (Test-Path $preCommitDReadme)) {
                $preCommitDReadmeHandled = $true
            }
        }
    }
    # Report every remaining entry (scripts, dotfiles, subdirs, non-iikit READMEs).
    # Skip the iikit-managed README we already recorded for removal — `-DryRun`
    # leaves it on disk, so Get-ChildItem would otherwise double-count it as
    # user content AND keep the dir from being reported as droppable.
    $remainingEntries = @(Get-ChildItem -Path $preCommitD -Force -ErrorAction SilentlyContinue |
        Where-Object { -not ($preCommitDReadmeHandled -and $_.FullName -eq $preCommitDReadme) })
    foreach ($entry in $remainingEntries) {
        $userContent.Add((To-Relative $entry.FullName)) | Out-Null
    }
    # Drop the dir only when it is empty after the README removal above
    if ($remainingEntries.Count -eq 0) {
        Remove-Path $preCommitD
    }
}

Remove-Path (Join-Path $repoRoot ".specify")

$techMd = Join-Path $repoRoot "TECH.md"
if ((Test-Path $techMd) -and ((Get-Content $techMd -Raw -ErrorAction SilentlyContinue) -match '/iikit-\d{2}-')) {
    Remove-Path $techMd
}

function Check-UserContent([string]$path) {
    if (Test-Path $path) {
        if ($RemoveUserContent) {
            Remove-Path $path
        } else {
            $userContent.Add((To-Relative $path)) | Out-Null
        }
    }
}

Check-UserContent (Join-Path $repoRoot "CONSTITUTION.md")
Check-UserContent (Join-Path $repoRoot "PREMISE.md")
Check-UserContent (Join-Path $repoRoot "specs")

$nextStep = "tessl uninstall tessl-labs/intent-integrity-kit"

if ($Json) {
    $result = [ordered]@{
        dry_run      = [bool]$DryRun
        removed      = @($removed)
        user_content = @($userContent)
        errors       = @($errors)
        next_step    = $nextStep
    }
    $result | ConvertTo-Json -Compress -Depth 3
} else {
    if ($DryRun) { Write-Host "[uninit] DRY RUN — no files changed" }
    if ($removed.Count -gt 0) {
        Write-Host "[uninit] Removed:"
        foreach ($p in $removed) { Write-Host "  - $p" }
    } else {
        Write-Host "[uninit] No tile-managed scaffolding found."
    }
    if ($userContent.Count -gt 0) {
        Write-Host ""
        Write-Host "[uninit] User-authored content kept (re-run with -RemoveUserContent to delete):"
        foreach ($p in $userContent) { Write-Host "  - $p" }
    }
    Write-Host ""
    Write-Host "[uninit] Next: $nextStep"
}

if ($errors.Count -gt 0) { exit 1 }
