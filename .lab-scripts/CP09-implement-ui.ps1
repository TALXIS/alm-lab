#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP09: Implement UI                                               ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# The UI solution: a model-driven app, sitemap navigation, forms, views and subgrids, plus
# form scripts, ribbon buttons and the TALXIS Grid PCF overlaid on the items subgrid
# (attached manifest-driven via `txc workspace control attach`, customized from Scripts.UI
# through the control's Client API). This completes the inner loop — a working app from
# source. The Grid control package itself is imported into the environment by CP10, before
# the app package.
#
# Solutions.UI does not own the tables: it references them (Behavior=Existing) from
# Solutions.DataModel and only layers forms, views and commands on top. A reference carries
# just enough metadata to attach UI components without duplicating the schema, which keeps
# DataModel the single owner of every table definition.
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
    . "$PSScriptRoot/scaffold/05e-grid-control.ps1"
    dotnet build --nologo --verbosity quiet
} finally { Pop-Location }

Save-Checkpoint -Id "cp09" -Message "Add warehouse model-driven app, views, forms, ribbon, and TALXIS Grid" -Body @'
Build the model-driven warehouse experience so users can navigate inventory data from a complete Dataverse app. This adds the app shell along with the core forms, views, scripts, and command surface, and swaps the stock items subgrid for the TALXIS Grid PCF customized from our own script library through the control's Client API.

## Changes
- add src/Solutions.UI with the warehouse model-driven application
- configure sitemap navigation, entity forms, views, and subgrids
- add form scripts and ribbon commands for warehouse workflows
- attach talxis_TALXIS.PCF.Grid to the Warehouse Items subgrid via txc workspace control attach (group by category, sum of quantity, low-stock highlighting from Scripts.UI)
## Testing
- dotnet build --nologo --verbosity quiet passes with the UI solution included
'@
Write-Host "`nNext: .lab-scripts/CP10-deploy-and-sync.ps1" -ForegroundColor Cyan
