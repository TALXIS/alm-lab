#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║              CP11: Integrate External Data (Custom Connector)                          ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Teaches the full round trip: external API -> custom connector -> code app -> Dataverse.
# A warehouse worker scans a product's barcode in the WarehousePicking code app; the app
# calls a custom connector to look up the product's catalog data; the result is upserted
# into a dedicated Product table and linked to the scanned Item.
#
# This checkpoint lands in stages, each its own reviewable update:
#   1. Data model: the Product table and the Item -> Product lookup column.
#   2. The custom connector project, deployed to Dev.
#   3. Wiring the connector and the Product table into the WarehousePicking code app.
#   4. Barcode-scanning UI that ties the whole flow together.
# All four run in this one script, each closed out by its own Save-Checkpoint - the PR/commit
# history is what makes them individually reviewable, not separate files to run by hand.
#
# Run:  .lab-scripts/CP11-integrate-external-data.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$PublisherName = Get-LabValue 'publisherName' 'ALMLab'
$PublisherPrefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP11 — Integrate external data (step 1: data model)"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/15-product-table.ps1"
    dotnet build --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) { Write-Err "dotnet build failed"; exit 1 }
} finally { Pop-Location }

Save-Checkpoint -Id "cp11" -Message "Add Product table and Item lookup for external data integration" -Body @'
Add the data model for external product-catalog integration: a dedicated Product table for barcode-sourced data (name, brand, quantity, image), and a lookup column linking Item to Product. No connector or UI yet - those land in follow-up checkpoint updates.

## Changes
- add Product table (EAN, Brand, Quantity, Image URL, Last Synced On) to Solutions.DataModel
- add Item.Product lookup column, pointing to Product
## Testing
- dotnet build --nologo --verbosity quiet passes from the repository root
'@

Write-Step "CP11 — Integrate external data (step 2: connector)"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/16-connector.ps1"
} finally { Pop-Location }

$devUrl = Get-LabValue 'devEnvUrl'
$devProfile = Get-LabValue 'devProfile'
if (-not $devUrl -or -not $devProfile) { Write-Err "Dev environment not found in lab state. Run CP04 first."; exit 1 }

if ($env:LAB_LOCAL_MODE) {
    Write-Info "LAB_LOCAL_MODE: skipped — would build Solutions.Connectors (Release) and run"
    Write-Info "  'txc env pkg import' to deploy it to Dev ($devUrl) on its own, independently"
    Write-Info "  of the rest of the app - the same way the Grid PCF control deploys in CP10."
} else {
    Write-Info "Building Solutions.Connectors (Release)..."
    Push-Location "$LabRoot/src/Solutions.Connectors"
    try {
        dotnet build -c Release --nologo --verbosity quiet
        if ($LASTEXITCODE -ne 0) { Write-Err "Solutions.Connectors build failed"; exit 1 }
    } finally { Pop-Location }

    $connectorPkg = Get-ChildItem (Join-Path $LabRoot "src/Solutions.Connectors/bin/Release") -Filter "Solutions.Connectors.zip" -Recurse | Select-Object -First 1
    if (-not $connectorPkg) { Write-Err "Solutions.Connectors.zip not found after build"; exit 1 }

    Write-Info "Deploying Solutions.Connectors to Dev environment ($devUrl)..."
    txc env pkg import $connectorPkg.FullName --profile $devProfile
    if ($LASTEXITCODE -ne 0) { Write-Err "Connector package import to Dev failed"; exit 1 }
    Write-Ok "Connectors.OpenFoodFacts deployed to Dev - try it in the maker portal's connector test pane before wiring it into the code app."
}

Save-Checkpoint -Id "cp11" -Message "Add Open Food Facts custom connector, deployed to Dev" -Body @'
Add the Connectors.OpenFoodFacts custom connector project (GET /product/{barcode}.json, no auth, custom code for the required User-Agent header and response flattening) packaged in its own Solutions.Connectors solution, and deploy it to the Dev environment. Deployed standalone - the code app is wired to it in a later checkpoint update.

## Changes
- add Connectors.OpenFoodFacts (ProjectType=Connector): real apiDefinition.swagger.json + script.csx for the Open Food Facts API
- add Solutions.Connectors, referencing Connectors.OpenFoodFacts
- deploy Solutions.Connectors to Dev via txc env pkg import
## Testing
- dotnet build succeeds for Solutions.Connectors
- connector appears in the Dev environment and returns real data from the maker portal's test pane for a known EAN (e.g. 3017620422003)
'@

Write-Step "CP11 — Integrate external data (step 3: wire connector + Product into the code app)"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/17-connector-datasource.ps1"
    Push-Location "$LabRoot/src/Apps.WarehousePicking"
    try {
        npm run build
        if ($LASTEXITCODE -ne 0) { Write-Err "npm run build failed"; exit 1 }
    } finally { Pop-Location }
} finally { Pop-Location }

Save-Checkpoint -Id "cp11" -Message "Wire the Product table and Open Food Facts connector into the code app" -Body @'
Register the Product table as a code app data source alongside the existing 3, and wire the Open Food Facts connector: typed model/service files plus a dataSourcesInfo.ts entry for its GetProductByBarcode operation, so the app can call it. Binding a live Dev connection (pa connection create + pa app add data-source --connector) is a separate, LAB_LOCAL_MODE-gated step here - run it once you have the connector deployed to get a working runtime connection.

## Changes
- add a Product data source to Apps.WarehousePicking (pp-app-code-data)
- add OpenFoodFactsModel.ts / OpenFoodFactsService.ts and a dataSourcesInfo.ts entry for the connector
- add @zxing/browser (camera barcode decoding) as a dependency
## Testing
- npm run build succeeds in src/Apps.WarehousePicking
'@

Write-Step "CP11 — Integrate external data (step 4: barcode scan UI)"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/18-barcode-scan-ui.ps1"
    Push-Location "$LabRoot/src/Apps.WarehousePicking"
    try {
        npm run build
        if ($LASTEXITCODE -ne 0) { Write-Err "npm run build failed"; exit 1 }
    } finally { Pop-Location }
} finally { Pop-Location }

Save-Checkpoint -Id "cp11" -Message "Add barcode scan UI to the item detail page" -Body @'
Add a "Scan Barcode" button to the item detail page. It opens a dialog that decodes a barcode with the device camera (or accepts one typed in manually), looks it up via the Open Food Facts connector, and on confirmation upserts a Product record (matched by EAN) and links it to the item.

## Changes
- add components/BarcodeScanDialog.tsx
- wire it into pages/warehouse-item-detail.tsx
## Testing
- npm run build succeeds in src/Apps.WarehousePicking
- manual: npm run dev, open an item, Scan Barcode, type a known EAN (e.g. 3017620422003), confirm the lookup preview and Link to Item
'@
Write-Host "`nNext: .lab-scripts/CP12-move-configuration.ps1" -ForegroundColor Cyan
