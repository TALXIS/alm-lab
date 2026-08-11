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
#
# After scaffolding and data-source generation, the placeholder UI is replaced with a real
# implementation (templates/05f-code-app/): an items list, an item detail with its
# transactions, and a transactions list — all built on the typed models and services that
# pp-app-code-data generated from the Solutions.DataModel metadata. All three tables are
# used: items and transactions drive the pages, locations resolve the item's location
# lookup (list column, detail card, New Item picker).
# Expects: $PublisherPrefix from parent scope.
#
# ──────────────────────────────────────────────────────────────────────────────────────────
#                                 Apps.WarehousePicking
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Code App: Warehouse Picking ──" -ForegroundColor Cyan

# Pin AppName so the CanvasApp schema name doesn't depend on the project folder name.
$appName = "warehousepicking"

txc workspace component create pp-app-code `
    --output "src/Apps.WarehousePicking" `
    --param "DisplayName=Warehouse Picking" `
    --param "AppName=$appName"
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ Apps.WarehousePicking scaffold failed" -ForegroundColor Red; throw "Apps.WarehousePicking scaffold failed" }

Write-Host "  ✓ Apps.WarehousePicking project created" -ForegroundColor Green
Write-Host "  ℹ CanvasApp schema name: ${PublisherPrefix}_$appName" -ForegroundColor DarkGray

# Add the code app project to the Visual Studio solution file (run from repo root)
dotnet sln add src/Apps.WarehousePicking
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ dotnet sln add Apps.WarehousePicking failed" -ForegroundColor Red; throw "dotnet sln add Apps.WarehousePicking failed" }

# Link the code app straight into Solutions.UI — no dedicated solution needed
dotnet add "src/Solutions.UI/Solutions.UI.csproj" reference "src/Apps.WarehousePicking/Apps.WarehousePicking.csproj"
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ ProjectReference Apps.WarehousePicking → Solutions.UI failed" -ForegroundColor Red; throw "ProjectReference Apps.WarehousePicking to Solutions.UI failed" }

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
# One pp-app-code-data invocation per table — three tables, three data sources.

# Warehouse Items — items list page, item detail page, item lookup in transaction forms
txc workspace component create pp-app-code-data `
    --output "src/Apps.WarehousePicking" `
    --param "EntityLogicalName=${PublisherPrefix}_warehouseitem" `
    --param "ModelSolutionPath=../Solutions.DataModel"
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ Data source ${PublisherPrefix}_warehouseitem failed" -ForegroundColor Red; throw "Data source ${PublisherPrefix}_warehouseitem failed" }
Write-Host "  ✓ Data source: ${PublisherPrefix}_warehouseitem" -ForegroundColor Green

# Warehouse Transactions — transactions list page, per-item transactions, create dialogs
txc workspace component create pp-app-code-data `
    --output "src/Apps.WarehousePicking" `
    --param "EntityLogicalName=${PublisherPrefix}_warehousetransaction" `
    --param "ModelSolutionPath=../Solutions.DataModel"
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ Data source ${PublisherPrefix}_warehousetransaction failed" -ForegroundColor Red; throw "Data source ${PublisherPrefix}_warehousetransaction failed" }
Write-Host "  ✓ Data source: ${PublisherPrefix}_warehousetransaction" -ForegroundColor Green

# Warehouse Locations — location names on the items list/detail, location pick on New Item
txc workspace component create pp-app-code-data `
    --output "src/Apps.WarehousePicking" `
    --param "EntityLogicalName=${PublisherPrefix}_warehouselocation" `
    --param "ModelSolutionPath=../Solutions.DataModel"
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ Data source ${PublisherPrefix}_warehouselocation failed" -ForegroundColor Red; throw "Data source ${PublisherPrefix}_warehouselocation failed" }
Write-Host "  ✓ Data source: ${PublisherPrefix}_warehouselocation" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                                   UI implementation
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# The pp-app-code template ships a placeholder home page. Replace it with the warehouse UI:
# router + layout + three pages wired to the generated services (react-query + shadcn/ui).
# The generated TS names derive from EntitySetName (e.g. Almlab_warehouseitemsService),
# hence the PascalCase prefix token next to the plain publisher prefix.
# Full sources: .lab-scripts/templates/05f-code-app/

Write-Host "`n── Code App UI ──" -ForegroundColor Cyan

$prefixPascal = [char]::ToUpper($PublisherPrefix[0]) + $PublisherPrefix.Substring(1)
$appSrc = "src/Apps.WarehousePicking/src"
$uiTokens = @{ PREFIX = $PublisherPrefix; PASCAL = $prefixPascal }

foreach ($file in @(
    @{ Template = "optionSets.ts";             Target = "utils/optionSets.ts" },
    @{ Template = "router.tsx";                Target = "router.tsx" },
    @{ Template = "_layout.tsx";               Target = "pages/_layout.tsx" },
    @{ Template = "warehouse-items.tsx";       Target = "pages/warehouse-items.tsx" },
    @{ Template = "warehouse-item-detail.tsx"; Target = "pages/warehouse-item-detail.tsx" },
    @{ Template = "transactions.tsx";          Target = "pages/transactions.tsx" }
)) {
    Expand-LabTemplate -Path "05f-code-app/$($file.Template)" `
        -Destination "$appSrc/$($file.Target)" `
        -Tokens $uiTokens
    Write-Host "  ✓ $($file.Target)" -ForegroundColor Green
}

# The router no longer references the template's placeholder home page
Remove-Item "$appSrc/pages/home.tsx" -ErrorAction SilentlyContinue

Write-Host "  ℹ Local preview: cd src/Apps.WarehousePicking && npm run dev" -ForegroundColor DarkGray
