#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP06: Implement data model                                       ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Inner loop begins. We scaffold the Package Deployer (Packages.Main) and the DataModel
# solution with three tables (Location, Item, Transaction) and their columns — all as code
# via the TALXIS DevKit CLI. The package references solutions so a single artifact deploys
# everything. Projects join the .slnx so 'dotnet build' orchestrates the whole monorepo.
#
# Run:  .lab-scripts/CP06-implement-data-model.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$PublisherName   = Get-LabValue 'publisherName'   'ALMLab'
$PublisherPrefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP06 — Data model"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/03a-package-deployer.ps1"
    . "$PSScriptRoot/scaffold/03b-data-model.ps1"
    . "$PSScriptRoot/scaffold/03c-columns.ps1"
    dotnet build --nologo --verbosity quiet
} finally { Pop-Location }

Save-Checkpoint -Id "cp06" -Message "Add warehouse data model schema and column definitions" -Body @'
Scaffold the core warehouse data model so inventory data can be stored and deployed from source. This introduces the package deployer, the data model solution, and the initial table and column definitions.

## Changes
- add src/Packages.Main as the package deployer entry point
- add src/Solutions.DataModel with warehouse location, item, and transaction tables
- define the initial Dataverse columns and references for the warehouse domain
## Testing
- dotnet build --nologo --verbosity quiet passes from the repository root
'@
Write-Host "`nNext: .lab-scripts/CP07-implement-backend.ps1" -ForegroundColor Cyan
