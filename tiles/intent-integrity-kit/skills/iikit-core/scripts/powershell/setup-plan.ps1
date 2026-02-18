#!/usr/bin/env pwsh
# DEPRECATED: Use check-prerequisites.ps1 -Phase 03
Write-Warning "DEPRECATED: setup-plan.ps1 is deprecated, use check-prerequisites.ps1 -Phase 03"
& "$PSScriptRoot/check-prerequisites.ps1" -Phase '03' @args
