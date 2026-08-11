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

if (-not (Get-LabValue 'codeAppScaffolded')) {
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

    # ──────────────────────────────────────────────────────────────────────────────────────
    #                                     Data Sources
    # ──────────────────────────────────────────────────────────────────────────────────────
    #
    # A code app talks to Dataverse through declared data sources. txc generates them from
    # the table metadata already sitting in src/Solutions.DataModel — no live environment
    # needed: typed models and services under src/generated, schema files under .power, and
    # the data source registration in power.config.json that the solution build packs with
    # the app.

    Write-Host "`n── Code App Data Sources ──" -ForegroundColor Cyan

    # ModelSolutionPath is resolved from the --output folder (the template runs its
    # post-actions there), so it points at the data model project relative to the code app.
    foreach ($table in @("warehouselocation", "warehouseitem", "warehousetransaction")) {
        $logicalName = "${PublisherPrefix}_$table"

        txc workspace component create pp-app-code-data `
            --output "src/Apps.WarehousePicking" `
            --param "EntityLogicalName=$logicalName" `
            --param "ModelSolutionPath=../Solutions.DataModel"
        if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ Data source $logicalName failed" -ForegroundColor Red; throw "Data source $logicalName failed" }

        Write-Host "  ✓ Data source: $logicalName" -ForegroundColor Green
    }

    # ──────────────────────────────────────────────────────────────────────────────────────
    #                                    Pages (picking UI)
    # ──────────────────────────────────────────────────────────────────────────────────────
    #
    # The base pp-app-code template already scaffolds a working starter (router, layout, a
    # counter-demo home page, providers for theme/toast/react-query — all untouched below).
    # We add the real warehouse-picking screens on top of it: an items list, an item detail
    # page with Pick/Restock actions, a global transactions ledger, and a locations list —
    # then wire them into the existing router/nav and drop the now-superseded demo page.

    Write-Host "`n── Code App Pages ──" -ForegroundColor Cyan

    # Pascal-cased prefix for generated identifiers (Almlab_warehouseitemsService etc.) —
    # txc's codegen title-cases just the first character of the publisher prefix.
    $prefixPascal = $PublisherPrefix.Substring(0,1).ToUpper() + $PublisherPrefix.Substring(1)

    foreach ($file in @(
        "utils/optionSets.ts",
        "pages/warehouse-items.tsx",
        "pages/warehouse-item-detail.tsx",
        "pages/transactions.tsx",
        "pages/locations.tsx"
    )) {
        $leaf = Split-Path $file -Leaf
        # Full source: .lab-scripts/templates/05f-code-app/<leaf>
        Expand-LabTemplate -Path "05f-code-app/$leaf" `
            -Destination "src/Apps.WarehousePicking/src/$file" `
            -Tokens @{ PREFIX = $PublisherPrefix; PREFIX_PASCAL = $prefixPascal }
    }
    Write-Host "  ✓ Pages authored: items, item detail, transactions, locations" -ForegroundColor Green

    # ── Patch the router: swap the demo home route for the real pages ─────────────────────
    $routerPath = "src/Apps.WarehousePicking/src/router.tsx"
    $routerContent = Get-Content -Raw -LiteralPath $routerPath

    $routerContent = $routerContent -replace [regex]::Escape('import HomePage from "@/pages/home"'), @'
import WarehouseItemsPage from "@/pages/warehouse-items"
import WarehouseItemDetailPage from "@/pages/warehouse-item-detail"
import TransactionsPage from "@/pages/transactions"
import LocationsPage from "@/pages/locations"
'@

    $routerContent = $routerContent -replace [regex]::Escape('<Layout showHeader={false} />'), '<Layout showHeader={true} />'

    $childrenPattern = [regex]::Escape('children: [') + '[\s\S]*?' + [regex]::Escape(']')
    $newChildren = @'
children: [
      { index: true, element: <WarehouseItemsPage /> },
      { path: "items/:id", element: <WarehouseItemDetailPage /> },
      { path: "transactions", element: <TransactionsPage /> },
      { path: "locations", element: <LocationsPage /> },
    ]
'@
    $routerContent = [regex]::Replace($routerContent, $childrenPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $newChildren })

    Set-Content -LiteralPath $routerPath -Value $routerContent -Encoding UTF8
    Write-Host "  ✓ router.tsx: items / item detail / transactions / locations routes" -ForegroundColor Green

    # ── Patch the layout: extend the nav past the single "Home" link ──────────────────────
    $layoutPath = "src/Apps.WarehousePicking/src/pages/_layout.tsx"
    $layoutContent = Get-Content -Raw -LiteralPath $layoutPath

    $navPattern = [regex]::Escape('<NavLink to="/" end') + '[\s\S]*?</NavLink>'
    $newNav = @'
<NavLink to="/" end
                className={({ isActive }) =>
                  `text-sm text-muted-foreground hover:text-foreground ${isActive ? "text-foreground font-medium" : ""}`
                }
              >
                Items
              </NavLink>
              <NavLink to="/transactions"
                className={({ isActive }) =>
                  `text-sm text-muted-foreground hover:text-foreground ${isActive ? "text-foreground font-medium" : ""}`
                }
              >
                Transactions
              </NavLink>
              <NavLink to="/locations"
                className={({ isActive }) =>
                  `text-sm text-muted-foreground hover:text-foreground ${isActive ? "text-foreground font-medium" : ""}`
                }
              >
                Locations
              </NavLink>
'@
    $layoutContent = [regex]::Replace($layoutContent, $navPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $newNav })

    Set-Content -LiteralPath $layoutPath -Value $layoutContent -Encoding UTF8
    Write-Host "  ✓ _layout.tsx nav: Items / Transactions / Locations" -ForegroundColor Green

    # ── Drop the now-superseded counter-demo home page ─────────────────────────────────────
    Remove-Item "src/Apps.WarehousePicking/src/pages/home.tsx" -ErrorAction SilentlyContinue
    Remove-Item "src/Apps.WarehousePicking/src/assets/react.svg" -ErrorAction SilentlyContinue
    Remove-Item "src/Apps.WarehousePicking/public/power-apps.svg" -ErrorAction SilentlyContinue
    Write-Host "  ✓ Removed demo home page + unused assets" -ForegroundColor Green

    Write-Host "  ℹ Local preview: cd src/Apps.WarehousePicking && npm run dev" -ForegroundColor DarkGray

    # Marks the whole block done — checked instead of Test-Path on the project csproj so a
    # re-run after a partial failure (e.g. scaffold succeeded but a page/patch step didn't)
    # retries everything rather than silently skipping the missing work.
    Set-LabValue 'codeAppScaffolded' $true
} else {
    Write-Host "  ✓ Apps.WarehousePicking (exists)" -ForegroundColor Green
}
