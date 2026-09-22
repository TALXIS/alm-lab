#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║              CP11: Integrate External Data (Custom Connector)                          ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Teaches the full round trip: external API -> custom connector -> code app -> Dataverse.
# A warehouse worker scans a product's barcode in the WarehousePicking code app; the app
# calls a custom connector (Open Food Facts, a public product database, no API key) to look
# up the product's name, brand, quantity, and image; the result is upserted into a
# dedicated Product table and linked to the scanned Item.
#
# This checkpoint lands in stages, each its own reviewable update:
#   1. Data model: the Product table and the Item -> Product lookup column (this step).
#   2. The Connectors.OpenFoodFacts custom connector project, deployed to Dev.
#   3. Wiring the connector and the Product table into the WarehousePicking code app.
#   4. Barcode-scanning UI that ties the whole flow together.
# Steps 2-4 aren't in the repo yet — this update only adds the data model they'll build on.
#
# Why a dedicated Product table instead of new columns on Item: Item already models what
# THIS warehouse tracks about its own stock (quantity on hand, location, category) - Product
# models externally-sourced catalog data for a barcode (name, brand, image) that's reusable
# across items and isn't itself warehouse-inventory data.
#
# Run:  .lab-scripts/CP11-integrate-external-data.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
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
Write-Host "`nNext: .lab-scripts/CP12-move-configuration.ps1" -ForegroundColor Cyan
