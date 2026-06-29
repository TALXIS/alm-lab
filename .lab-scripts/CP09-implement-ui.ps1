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

Save-Checkpoint -Id "cp09" -Message "Add warehouse model-driven app, views, forms, and ribbon" -Body @'
Build the model-driven warehouse experience so users can navigate inventory data from a complete Dataverse app. This adds the app shell along with the core forms, views, scripts, and command surface.

## Changes
- add src/Solutions.UI with the warehouse model-driven application
- configure sitemap navigation, entity forms, views, and subgrids
- add form scripts and ribbon commands for warehouse workflows
## Testing
- dotnet build --nologo --verbosity quiet passes with the UI solution included
'@
Write-Host "`nNext: .lab-scripts/CP10-move-configuration.ps1" -ForegroundColor Cyan
