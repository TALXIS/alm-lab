#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║      05f: Code App — Warehouse Picking (Vite + React + TypeScript + Fluent UI)         ║
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
# transactions, a transactions list and a locations list — all built on the typed models
# and services that pp-app-code-data generated from the Solutions.DataModel metadata.
# The UI uses Fluent UI React v9 (@fluentui/react-components) — the same design language as
# Power Apps and the rest of Microsoft 365 — in place of the starter's shadcn/ui + Tailwind.
# All three tables get their own page; locations additionally resolve the item's location
# lookup (list column, detail card, New Item picker) and show a per-location item count.
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
# A code app talks to Dataverse through declared data sources. txc generates them from
# the table metadata already sitting in src/Solutions.DataModel — no live environment
# needed: typed models and services under src/generated, schema files under .power, and
# the data source registration in power.config.json that the solution build packs with
# the app.

Write-Host "`n── Code App Data Sources ──" -ForegroundColor Cyan

# ModelSolutionPath is resolved from the --output folder (the template runs its
# post-actions there), so it points at the data model project relative to the code app.
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
#                                 Fluent UI app shell
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# The base pp-app-code template ships a shadcn/ui starter: Radix-based components copied
# into src/components/ui, Tailwind for styling, sonner for toasts, lucide for icons. We swap
# that whole layer for Fluent UI React v9 — Microsoft's design system, so the picking app
# looks like it belongs next to the model-driven app and the rest of Power Apps:
#   - FluentProvider (light/dark theme following the OS) + Fluent's Toaster replace the
#     starter's ThemeProvider/SonnerProvider in App.tsx
#   - components come from @fluentui/react-components, icons from @fluentui/react-icons,
#     and styling is Fluent's makeStyles + design tokens instead of Tailwind classes
# React Query, react-router and @microsoft/power-apps stay exactly as the starter set them up.

Write-Host "`n── Code App UI: Fluent UI ──" -ForegroundColor Cyan

$appRoot = "src/Apps.WarehousePicking"
$appSrc = "$appRoot/src"

# Starter files that only exist for the shadcn/Tailwind layer (or its theme/toast wiring)
foreach ($path in @(
    "components/ui",
    "components/mode-toggle.tsx",
    "providers/theme-provider.tsx",
    "providers/sonner-provider.tsx",
    "hooks/use-theme.ts",
    "lib"
)) {
    Remove-Item "$appSrc/$path" -Recurse -Force -ErrorAction SilentlyContinue
}
Remove-Item "$appRoot/components.json" -ErrorAction SilentlyContinue
Write-Host "  ✓ Removed shadcn/ui components, Tailwind and sonner wiring" -ForegroundColor Green

# Swap the dependencies in package.json only — the DevKit build (and `npm run dev`) runs
# npm install anyway, so there's nothing to download here.
Push-Location $appRoot
try {
    # Packages only the shadcn/ui components, Tailwind, sonner and lucide pulled in
    npm pkg delete `
        "dependencies.@radix-ui/react-checkbox" "dependencies.@radix-ui/react-dialog" `
        "dependencies.@radix-ui/react-dropdown-menu" "dependencies.@radix-ui/react-label" `
        "dependencies.@radix-ui/react-popover" "dependencies.@radix-ui/react-progress" `
        "dependencies.@radix-ui/react-select" "dependencies.@radix-ui/react-separator" `
        "dependencies.@radix-ui/react-slot" "dependencies.@radix-ui/react-tabs" `
        "dependencies.@radix-ui/react-tooltip" `
        "dependencies.@tailwindcss/vite" "dependencies.tailwindcss" "devDependencies.tw-animate-css" `
        "dependencies.class-variance-authority" "dependencies.clsx" "dependencies.tailwind-merge" `
        "dependencies.cmdk" "dependencies.react-day-picker" "dependencies.recharts" `
        "dependencies.sonner" "dependencies.lucide-react"
    if ($LASTEXITCODE -ne 0) { throw "npm pkg delete (shadcn/Tailwind packages) failed" }

    npm pkg set "dependencies.@fluentui/react-components=^9.74.9" "dependencies.@fluentui/react-icons=^2.0.344"
    if ($LASTEXITCODE -ne 0) { throw "npm pkg set (Fluent UI packages) failed" }
} finally { Pop-Location }
Write-Host "  ✓ package.json: @fluentui/react-components + @fluentui/react-icons" -ForegroundColor Green

foreach ($file in @(
    @{ Template = "vite.config.ts"; Target = "vite.config.ts" },
    @{ Template = "index.css";      Target = "src/index.css" },
    @{ Template = "App.tsx";        Target = "src/App.tsx" },
    @{ Template = "use-notify.tsx"; Target = "src/hooks/use-notify.tsx" },
    @{ Template = "RouterLink.tsx"; Target = "src/components/RouterLink.tsx" },
    @{ Template = "PageHeader.tsx"; Target = "src/components/PageHeader.tsx" },
    @{ Template = "not-found.tsx";  Target = "src/pages/not-found.tsx" }
)) {
    Expand-LabTemplate -Path "05f-code-app/$($file.Template)" -Destination "$appRoot/$($file.Target)"
    Write-Host "  ✓ $($file.Target)" -ForegroundColor Green
}

# ──────────────────────────────────────────────────────────────────────────────────────────
#                                    Pages (picking UI)
# ──────────────────────────────────────────────────────────────────────────────────────────
#
# On top of the Fluent shell we add the real warehouse screens: an items list, an item
# detail page with its transactions, a global transactions ledger, and a locations list —
# then wire them into the router/nav and drop the starter's counter-demo page.
# Full sources: .lab-scripts/templates/05f-code-app/

Write-Host "`n── Code App Pages ──" -ForegroundColor Cyan

# Pascal-cased prefix for generated identifiers (Almlab_warehouseitemsService etc.) —
# txc's codegen title-cases just the first character of the publisher prefix.
$prefixPascal = [char]::ToUpper($PublisherPrefix[0]) + $PublisherPrefix.Substring(1)
$uiTokens = @{ PREFIX = $PublisherPrefix; PASCAL = $prefixPascal }

foreach ($file in @(
    @{ Template = "optionSets.ts";             Target = "utils/optionSets.ts" },
    @{ Template = "router.tsx";                Target = "router.tsx" },
    @{ Template = "_layout.tsx";               Target = "pages/_layout.tsx" },
    @{ Template = "warehouse-items.tsx";       Target = "pages/warehouse-items.tsx" },
    @{ Template = "warehouse-item-detail.tsx"; Target = "pages/warehouse-item-detail.tsx" },
    @{ Template = "transactions.tsx";          Target = "pages/transactions.tsx" },
    @{ Template = "locations.tsx";             Target = "pages/locations.tsx" }
)) {
    Expand-LabTemplate -Path "05f-code-app/$($file.Template)" `
        -Destination "$appSrc/$($file.Target)" `
        -Tokens $uiTokens
    Write-Host "  ✓ $($file.Target)" -ForegroundColor Green
}

# Drop the now-superseded counter-demo home page — the router no longer references it
Remove-Item "$appSrc/pages/home.tsx" -ErrorAction SilentlyContinue

Write-Host "  ℹ Local preview: cd src/Apps.WarehousePicking && npm run dev" -ForegroundColor DarkGray
