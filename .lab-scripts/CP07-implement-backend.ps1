#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP07: Implement backend                                          ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Server-side logic: a plugin project (validates transactions, subtracts stock) and the
# Logic solution that registers the SDK message processing steps. Plugins are C#, compiled
# by dotnet build and packaged for deployment.
#
# Note the split: Plugins.Warehouse holds the code, Solutions.Logic holds the registration.
# The assembly is a build artifact; where and when it runs is Dataverse configuration, and
# each belongs to its own project.
#
# Stage choice matters: ValidateWarehouseTransaction runs in Pre-validation - before the
# database transaction starts - the cheapest place to reject bad input with an
# InvalidPluginExecutionException. SubtractQuantity runs in Post-operation: the record is
# already written but still inside the transaction, so the stock update and the transaction
# record commit or roll back together.
#
# Run:  .lab-scripts/CP07-implement-backend.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$PublisherName   = Get-LabValue 'publisherName'   'ALMLab'
$PublisherPrefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP07 — Backend (plugins + logic)"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/07-plugins.ps1"
    . "$PSScriptRoot/scaffold/08-logic-solution.ps1"
    dotnet build --nologo --verbosity quiet
} finally { Pop-Location }

Save-Checkpoint -Id "cp07" -Message "Add inventory transaction plugin and logic solution steps" -Body @'
Introduce server-side inventory logic so warehouse transactions are validated and stock is updated automatically. The new plugin project is packaged through a dedicated Dataverse logic solution.

## Changes
- add src/Plugins.Warehouse with validation and quantity update plugins
- add src/Solutions.Logic with the plugin assembly registration
- register pre-validation and post-operation steps for transaction creation
## Testing
- dotnet build --nologo --verbosity quiet passes with the new plugin and logic projects
'@
Write-Host "`nNext: .lab-scripts/CP08-implement-security.ps1" -ForegroundColor Cyan
