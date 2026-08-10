#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║           05f: Code App — Warehouse Picking (Vite + React + TypeScript)                ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Creates Apps.WarehousePicking — a Power Apps code app: a fully custom SPA hosted by Power
# Apps, built with Vite, React and TypeScript instead of Dataverse metadata. Two personas,
# two UI styles: Solutions.UI's model-driven app is the back-office view for office staff
# (full CRUD, grids, everything CP08's Warehouse Manager/Worker roles cover); this code app
# is the narrow, fast, task-focused screen a warehouse floor worker uses to pick a
# transaction — a code app's custom UI is the right tool for that, a general-purpose
# CRUD grid is not.
#
# It's consumed by Solutions.UI as a plain ProjectReference — the DevKit build has no
# separate-solution requirement for a CodeApp project, it discovers and builds any
# ProjectType=CodeApp reference regardless of which solution carries it, so this rides
# alongside the model-driven components instead of needing its own solution project.
# During the solution build the DevKit runs npm install / npm run build, registers the app
# as a CanvasApp root component and packs dist/ into the solution.
# Expects: $PublisherPrefix from parent scope.
#
# ──────────────────────────────────────────────────────────────────────────────────────────
#                                 Apps.WarehousePicking
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Code App: Warehouse Picking ──" -ForegroundColor Cyan

# AppName drives the CanvasApp schema name (<prefix>_<appname>), the generated .meta.xml file
# name and the package folder inside the solution. Pin it explicitly so those names stay
# predictable instead of being derived from the project folder name (src/Apps.WarehousePicking
# would otherwise produce the dotted, redundant-looking apps.warehousepicking).
$appName = "warehousepicking"

txc workspace component create pp-app-code `
    --output "src/Apps.WarehousePicking" `
    --param "DisplayName=Warehouse Picking" `
    --param "AppName=$appName"
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ Apps.WarehousePicking scaffold failed" -ForegroundColor Red; exit 1 }

Write-Host "  ✓ Apps.WarehousePicking project created" -ForegroundColor Green
Write-Host "  ℹ CanvasApp schema name: ${PublisherPrefix}_$appName" -ForegroundColor DarkGray

# Add the code app project to the Visual Studio solution file (run from repo root)
dotnet sln add src/Apps.WarehousePicking
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ dotnet sln add Apps.WarehousePicking failed" -ForegroundColor Red; exit 1 }

# Link the code app straight into Solutions.UI — no dedicated solution needed
dotnet add "src/Solutions.UI/Solutions.UI.csproj" reference "src/Apps.WarehousePicking/Apps.WarehousePicking.csproj"
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ ProjectReference Apps.WarehousePicking → Solutions.UI failed" -ForegroundColor Red; exit 1 }

Write-Host "  ✓ ProjectReference: Apps.WarehousePicking → Solutions.UI" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                                     Data Sources
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# A code app talks to Dataverse through declared data sources. txc generates them from the
# table metadata already sitting in src/Solutions.DataModel — no live environment needed:
# typed models and services under src/generated, schema files under .power, and the data
# source registration in power.config.json that the solution build packs with the app.

Write-Host "`n── Code App Data Sources ──" -ForegroundColor Cyan

# ModelSolutionPath is resolved from the --output folder (the template runs its post-actions
# there), so it points at the data model project relative to the code app project.
foreach ($table in @("warehouselocation", "warehouseitem", "warehousetransaction")) {
    $logicalName = "${PublisherPrefix}_$table"

    txc workspace component create pp-app-code-data `
        --output "src/Apps.WarehousePicking" `
        --param "EntityLogicalName=$logicalName" `
        --param "ModelSolutionPath=../Solutions.DataModel"
    if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ Data source $logicalName failed" -ForegroundColor Red; exit 1 }

    Write-Host "  ✓ Data source: $logicalName" -ForegroundColor Green
}

Write-Host "  ℹ Local preview: cd src/Apps.WarehousePicking && npm run dev" -ForegroundColor DarkGray
