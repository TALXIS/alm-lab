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
# Packages.Main builds to a .pdpkg.zip - the single deployment artifact. It bundles every
# referenced solution plus ImportConfig.xml, which drives the import order (derived from
# the ProjectReferences, so dependencies always install first) and can run custom .NET
# import logic such as data import, validation or post-deploy steps.
#
# DataModel is also the first slice of a deliberate layering: one solution per concern
# (DataModel now, then Logic, Security and UI in CP07-09). Small single-purpose solutions
# keep ownership clear and reviews focused - schema changes never hide inside UI diffs.
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
    if ($LASTEXITCODE -ne 0) { Write-Err "dotnet build failed"; exit 1 }
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
