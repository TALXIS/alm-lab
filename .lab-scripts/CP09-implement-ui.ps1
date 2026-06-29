#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP09: Implement UI                                               ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# The UI solution: a model-driven app, sitemap navigation, forms, views and subgrids, plus
# form scripts and ribbon buttons. This completes the inner loop — a working app from source.
#
# Run:  .lab-scripts/CP09-implement-ui.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$PublisherName   = Get-LabValue 'publisherName'   'ALMLab'
$PublisherPrefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP09 — UI"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/05a-ui-solution.ps1"
    . "$PSScriptRoot/scaffold/05b-sitemap.ps1"
    . "$PSScriptRoot/scaffold/05c-forms.ps1"
    . "$PSScriptRoot/scaffold/05d-views-subgrids.ps1"
    . "$PSScriptRoot/scaffold/09-form-scripts.ps1"
    . "$PSScriptRoot/scaffold/10-ribbon.ps1"
    dotnet build --nologo --verbosity quiet
} finally { Pop-Location }

Save-Checkpoint -Id "cp09" -Message "ui: app, sitemap, forms, views, scripts, ribbon"
Write-Host "`nNext: .lab-scripts/CP10-move-configuration.ps1" -ForegroundColor Cyan
