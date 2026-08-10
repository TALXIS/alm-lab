#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                  CP15: Implement grid control (TALXIS Grid)                            ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# The stock subgrid from CP09 is read-only and plain. This checkpoint swaps it for the
# TALXIS Grid — an open-source PCF control that adds grouping, aggregations, inline
# filtering and a Client API — and shows the full source-first loop for a third-party
# control:
#   1. The control ships as a public Package Deployer package on nuget.org
#      (TALXIS.Controls.Grid.Package) — no private feed, no manual solution import.
#   2. `txc workspace control attach` overlays talxis_TALXIS.PCF.Grid on the existing
#      Warehouse Items subgrid — manifest-driven: the CLI downloads the NuGet package
#      itself, reads the parameter schema from its ControlManifest.xml, validates our
#      values, and writes the controlDescriptions overlay. Groups by category, sums
#      quantities. No file juggling: both attach and the Dev import below take the
#      plain package name.
#   3. Our own web resource customizes the grid at runtime: the control calls
#      WarehouseScripts.GridApi.onDatasetControlInitialized (ClientApi parameters in
#      FormXml), the script registers interceptors and record expressions — column
#      rename + red cells when stock falls to the reorder point.
#   4. The bridge is unit-tested with Jest like everything else in Scripts.Tests.
#
# Import order matters when deploying: the Grid solution must land in the environment
# BEFORE our app package, because the patched form now references the custom control.
#
# The Grid is licensed by NETWORG (free for non-commercial use) — see
# https://github.com/TALXIS/tools-controls for terms before using it commercially.
#
# Run:  .lab-scripts/CP15-implement-grid-control.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$PublisherName   = Get-LabValue 'publisherName'   'ALMLab'
$PublisherPrefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP15 — TALXIS Grid control + script customization"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/15-grid-control.ps1"

    # ── Build — validates the patched FormXml and compiles the new TypeScript ──
    Write-Info "Building the solution..."
    dotnet build --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) { Write-Err "Build failed"; exit 1 }
    Write-Ok "Solution builds with the Grid overlay"

    # ── Test — the GridApi bridge rides the CP14 Jest harness ──
    Write-Info "Running script unit tests (dotnet test → Jest)..."
    dotnet test src/Scripts.Tests/Scripts.Tests.csproj --nologo
    if ($LASTEXITCODE -ne 0) { Write-Err "Script tests failed"; exit 1 }
    Write-Ok "GridApi bridge tests passed"

    # ── Deploy — Grid control first, then the updated app package (mirrors CP10) ──
    $devUrl = Get-LabValue 'devEnvUrl'
    if ($devUrl) {
        Write-Info "Importing TALXIS Grid control package to Dev ($devUrl)..."
        txc env pkg import $gridPackage --version $gridVersion --profile dev
        if ($LASTEXITCODE -ne 0) { Write-Err "Grid package import failed"; exit 1 }
        Write-Ok "TALXIS Grid control deployed"

        Write-Info "Building and deploying Packages.Main..."
        $publishDir = Join-Path $LabRoot ".lab-scripts/.tmp-deploy"
        Remove-Item $publishDir -Recurse -Force -ErrorAction SilentlyContinue
        dotnet publish src/Packages.Main/Packages.Main.csproj -c Release -o $publishDir --nologo --verbosity quiet
        if ($LASTEXITCODE -ne 0) { Write-Err "dotnet publish failed"; exit 1 }
        $pdpkg = Get-ChildItem "src/Packages.Main/bin/Release" -Filter "*.pdpkg.zip" -Recurse | Select-Object -First 1
        txc env pkg import $pdpkg.FullName --profile dev
        if ($LASTEXITCODE -ne 0) { Write-Err "Package import to Dev failed"; exit 1 }
        Remove-Item $publishDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok "Grid live on the Warehouse Location form in Dev — open a location record to see it"
    } else {
        Write-Warn2 "No Dev environment in lab state — skipping deploy (run CP04 + CP10 to see the grid live)"
    }

} finally { Pop-Location }

Save-Checkpoint -Id "cp15" -Message "Add TALXIS Grid control with form script customization" -Body @'
Swap the stock subgrid on the Warehouse Location form for the TALXIS Grid PCF and customize it from our own script library through the control's Client API. The Grid ships as a public Package Deployer package from nuget.org, and the overlay is applied with `txc workspace control attach` — the CLI reads the parameter schema from the control's own manifest, so no per-control template is needed. The bridge (getDataset / onDatasetControlInitialized) lives in our almlab_main.js web resource, so no private TALXIS feed is needed either.

## Changes
- attach talxis_TALXIS.PCF.Grid to the Warehouse Items subgrid via txc workspace control attach (group by category, sum of quantity)
- wire the location↔item relationship into the subgrid so it shows only related items
- add GridApi bridge + interceptors + low-stock formatting to src/Scripts.UI, register onLoad on the location form
- add Jest tests for the bridge in src/Scripts.Tests
## Testing
- dotnet build + Jest bridge tests pass locally
- grid renders grouped with aggregates on the Warehouse Location form in Dev, low-stock cells highlighted
'@
Write-Host "`n✓ Lab complete — you built, tested and shipped a Power Platform app from source!" -ForegroundColor Green
