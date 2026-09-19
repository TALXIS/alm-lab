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

# KNOWN LIMITATION (TALXIS DevKit P12): the page below is scaffolded, referenced into
# Solutions.UI and given a sitemap subarea, but it will NOT reach the environment through the
# deployment package. SolutionPackager has no support for the uxagentproject component type
# (SolutionPackagerLib contains no reference to it, against 14 for CanvasApp), so it silently
# drops the staged uxagentprojects/ folder at pack time. TALXIS's own reference implementation
# in docs-patterns-practices/bdd-agent-v2 comments the GenPage ProjectReference out for the
# same reason. Until that is fixed the Dashboard subarea points at a page the environment does
# not have, and the page has to be pushed separately:
#
#   pac model genpage upload --app-id <appid> --page-id <GenPageId from the csproj> \
#     --code-file src/GenPages.Dashboard/page.tsx --name "Warehouse Dashboard" \
#     --data-sources "<prefix>_warehouseitem,<prefix>_warehouselocation" --prompt "..."
#
# Passing the scaffolded GenPageId keeps the sitemap subarea and the uploaded page in sync.

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

# The DevKit transpiles page.tsx by handing the file straight to tsc, which makes tsc ignore
# tsconfig.json and fall back to classic module resolution — bare specifiers like 'react' and
# '@fluentui/react-components' are then never looked up in node_modules and every import fails
# with TS2792. The transpile still emits JS, but MSBuild turns tsc's output into build errors,
# so the solution won't build without these ambient declarations. page.tsx references this file
# with a triple-slash directive. See the file header for the full explanation.
Expand-LabTemplate -Path "12-genpage-dashboard/genpage-ambient.d.ts" `
    -Destination "src/GenPages.Dashboard/genpage-ambient.d.ts"
Write-Host "  ✓ genpage-ambient.d.ts written (tsc module resolution shim)" -ForegroundColor Green

# genpage.config.json ships as the page's config.json inside the solution. The scaffold leaves
# dataSources empty; the page reads two tables, so register them or the deployed page has no
# data to query.
$genPageConfig = @{
    dataSources = @("${PublisherPrefix}_warehouseitem", "${PublisherPrefix}_warehouselocation")
    model       = ""
} | ConvertTo-Json -Depth 5
Set-Content -LiteralPath "src/GenPages.Dashboard/genpage.config.json" -Value $genPageConfig -Encoding UTF8
Write-Host "  ✓ genpage.config.json data sources registered" -ForegroundColor Green

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
    --param "GroupTitle=Overview" `
    --param "AreaTitle=Warehouse" `
    --param "AppName=${PublisherPrefix}_warehouseapp"

Write-Host "  ✓ Sitemap subarea: Dashboard (genpage)" -ForegroundColor Green

# The subarea lands in a new "Overview" group, but txc appends that group after the existing
# ones, so the dashboard would sit below the entity lists. Move the group holding the
# generative page to the top of its area - an overview page is the first thing a user should
# see, not the last.
$siteMapPath = "src/Solutions.UI/AppModuleSiteMaps/${PublisherPrefix}_warehouseapp/AppModuleSiteMap.xml"
if (Test-Path $siteMapPath) {
    $siteMapXml = New-Object System.Xml.XmlDocument
    $siteMapXml.PreserveWhitespace = $true
    $siteMapXml.Load((Resolve-Path $siteMapPath).Path)

    $areaNode = $siteMapXml.SelectSingleNode("//AppModuleSiteMap/SiteMap/Area")
    $genPageGroup = $siteMapXml.SelectSingleNode("//AppModuleSiteMap/SiteMap/Area/Group[SubArea/@GenPageId]")

    if ($areaNode -and $genPageGroup -and $areaNode.FirstChild -ne $genPageGroup) {
        [void]$areaNode.RemoveChild($genPageGroup)
        [void]$areaNode.InsertBefore($genPageGroup, $areaNode.FirstChild)
        $siteMapXml.Save((Resolve-Path $siteMapPath).Path)
        Write-Host "  ✓ Overview group moved to the top of the Warehouse area" -ForegroundColor Green
    }
}
