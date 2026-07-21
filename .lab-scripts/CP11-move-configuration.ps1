#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP11: Move configuration                                         ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Reference data (e.g. warehouse locations) must travel with the app, not be re-keyed per
# environment. The Configuration Migration Tool (CMT) via txc moves records the same way
# solutions move metadata - and just like metadata, the records themselves can be SOURCE:
# an authored data.xml with stable GUIDs that any environment imports identically.
#
# The flow, all from source control:
#   1. Author the CMT package (schema + seed records + OPC manifest) beside the Package
#      Deployer - records as code, reviewable in a PR (scaffold/13-config-data.ps1).
#   2. Import it into Dev - the app instantly has data to work with.
#   3. Round-trip: export from Dev back into the same package - any records you added
#      by hand in the maker portal get captured as source (the data twin of
#      'txc env solution pull' from CP10).
#   4. Import into Test - config stays consistent across environments; in CI the package
#      deploys alongside the solutions.
#
# Run:  .lab-scripts/CP11-move-configuration.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$PublisherPrefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP11 — Configuration data (CMT)"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/13-config-data.ps1"

    $dataDir = Join-Path $LabRoot "src/Packages.Main/Data"
    Set-LabValue 'configDataDirectory'  $dataDir
    Set-LabValue 'configDataSchemaPath' (Join-Path $dataDir "data_schema.xml")
    Set-LabValue 'configDataFilePath'   (Join-Path $dataDir "data.xml")

    # Step 1: Import the seed package into Dev — the app now has data.
    txc data pkg import $dataDir --profile dev --allow-production
    if ($LASTEXITCODE -ne 0) { Write-Err "Seed import to Dev failed"; exit 1 }
    Write-Ok "Seed data imported to Dev"

    # Step 2: Round-trip — export Dev data back into the package. Records added by hand
    # in the maker portal get captured as source, same idea as the CP10 solution pull.
    txc data pkg export --schema (Join-Path $dataDir "data_schema.xml") --output $dataDir --overwrite --profile dev --allow-production
    if ($LASTEXITCODE -ne 0) { Write-Err "Config export from Dev failed"; exit 1 }
    Write-Ok "Dev data exported back to source"

    # Step 3: Import into Test — config travels with the app, no re-keying per environment.
    txc data pkg import $dataDir --profile test --allow-production
    if ($LASTEXITCODE -ne 0) { Write-Err "Config import failed"; exit 1 }
    Set-LabValue 'configImportedToUrl' (Get-LabValue 'testEnvUrl')
    Write-Ok "Config imported to Test"
} finally { Pop-Location }

Save-Checkpoint -Id "cp11" -Message "Add configuration data package for environment promotion" -Body @'
Package warehouse reference data so environments stay consistent as the app moves through ALM stages. The CMT package is authored as source (seed records with stable GUIDs), imported into Dev, round-tripped back from Dev, and imported into Test.

## Changes
- add src/Packages.Main/Data/data_schema.xml covering the three warehouse tables
- add src/Packages.Main/Data/data.xml with seed locations, items, and transactions
- add the [Content_Types].xml OPC manifest required by the CMT package format
- import the package into Dev and Test; export captures manual Dev records as source
## Testing
- txc data package import and export complete successfully against Dev and Test
'@
Write-Host "`nNext: .lab-scripts/CP12-extend-branch-policies-build-checks.ps1" -ForegroundColor Cyan
