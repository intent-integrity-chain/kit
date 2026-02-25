#!/usr/bin/env pwsh
# DEPRECATED: Use check-prerequisites.ps1 -Phase 02
Write-Warning "DEPRECATED: setup-plan.ps1 is deprecated, use check-prerequisites.ps1 -Phase 02"
& "$PSScriptRoot/check-prerequisites.ps1" -Phase '02' @args
