#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║         12: Generative Page — Warehouse Dashboard (React 17 + Fluent UI V9)            ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Creates a generative page project with a warehouse inventory dashboard.
# The page uses props.dataApi to query Dataverse tables and renders summary
# cards (total items, locations, low stock alerts) plus an inventory table.
#
# Expects: $PublisherPrefix from parent scope.
#
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Generative Page: Warehouse Dashboard ──" -ForegroundColor Cyan

# ──────────────────────────────────────────────────────────────────────────────────────────
#                            Scaffold GenPage Project
# ──────────────────────────────────────────────────────────────────────────────────────────

txc workspace component create pp-page-generative `
    --output "src/GenPages.Dashboard" `
    --param "Name=warehousedashboard" `
    --param "DisplayName=Warehouse Dashboard"

Write-Host "  ✓ GenPages.Dashboard project created" -ForegroundColor Green

# Find the generated csproj dynamically (template names it after the --param "Name" value)
$csprojFile = Get-ChildItem "src/GenPages.Dashboard/*.csproj" | Select-Object -First 1
if (-not $csprojFile) { throw "No .csproj found in src/GenPages.Dashboard — scaffold may have failed" }
$csprojPath = $csprojFile.FullName
$csprojRelPath = $csprojFile.Name
Write-Host "  ℹ GenPages csproj: $csprojRelPath" -ForegroundColor DarkGray

$csprojXml = [xml](Get-Content $csprojPath -Raw)
$genPageId = $csprojXml.Project.PropertyGroup.GenPageId | Where-Object { $_ }
Write-Host "  ℹ GenPageId: $genPageId" -ForegroundColor DarkGray

# ──────────────────────────────────────────────────────────────────────────────────────────
#                           Customize page.tsx — Dashboard
# ──────────────────────────────────────────────────────────────────────────────────────────

# Full source: .lab-scripts/templates/12-genpage-dashboard/page.tsx
Expand-LabTemplate -Path "12-genpage-dashboard/page.tsx" `
    -Destination "src/GenPages.Dashboard/page.tsx" `
    -Tokens @{ PREFIX = $PublisherPrefix }
Write-Host "  ✓ page.tsx customized as warehouse dashboard" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                       Add ProjectReference from Solutions.UI
# ──────────────────────────────────────────────────────────────────────────────────────────

cd src/Solutions.UI
dotnet add "./Solutions.UI.csproj" reference "../GenPages.Dashboard/$csprojRelPath"
cd ../..
Write-Host "  ✓ ProjectReference: GenPages.Dashboard → Solutions.UI" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                       Sitemap Subarea (PageType=genpage)
# ──────────────────────────────────────────────────────────────────────────────────────────

txc workspace component create pp-sitemap-subarea `
    --output "src/Solutions.UI" `
    --param "PageType=genpage" `
    --param "Title=Dashboard" `
    --param "EntityLogicalName=${PublisherPrefix}_warehouseitem" `
    --param "GenPageId=$genPageId" `
    --param "GroupTitle=Management" `
    --param "AreaTitle=Warehouse" `
    --param "AppName=${PublisherPrefix}_warehouseapp"

Write-Host "  ✓ Sitemap subarea: Dashboard (genpage)" -ForegroundColor Green
