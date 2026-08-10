#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║           05g: Code App — Warehouse Portal (Vite + React + TypeScript)                 ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Creates CodeApps.Warehouse — a Power Apps code app: a fully custom SPA hosted by Power
# Apps, built with Vite, React and TypeScript instead of Dataverse metadata. It is consumed
# by Solutions.CodeApp the same way Plugins.Warehouse is consumed by Solutions.Logic: as a
# plain ProjectReference. During the solution build the DevKit runs npm install / npm run
# build, registers the app as a CanvasApp root component and packs dist/ into the solution.
# Expects: $PublisherPrefix from parent scope.
#
# ──────────────────────────────────────────────────────────────────────────────────────────
#                                 CodeApps.Warehouse
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Code App: Warehouse Portal ──" -ForegroundColor Cyan

txc workspace component create pp-app-code `
    --output "src/CodeApps.Warehouse" `
    --param "DisplayName=Warehouse Portal"
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ CodeApps.Warehouse scaffold failed" -ForegroundColor Red; exit 1 }

Write-Host "  ✓ CodeApps.Warehouse project created" -ForegroundColor Green

# Add the code app project to the Visual Studio solution file (run from repo root)
dotnet sln add src/CodeApps.Warehouse
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ dotnet sln add CodeApps.Warehouse failed" -ForegroundColor Red; exit 1 }

# Link the code app to its solution — this is what makes the solution pack the built SPA
dotnet add "src/Solutions.CodeApp/Solutions.CodeApp.csproj" reference "src/CodeApps.Warehouse/CodeApps.Warehouse.csproj"
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ ProjectReference CodeApps.Warehouse → Solutions.CodeApp failed" -ForegroundColor Red; exit 1 }

Write-Host "  ✓ ProjectReference: CodeApps.Warehouse → Solutions.CodeApp" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                              Project File Adjustments
# ──────────────────────────────────────────────────────────────────────────────────────────

$csprojFile = Get-ChildItem "src/CodeApps.Warehouse/*.csproj" | Select-Object -First 1
if (-not $csprojFile) { throw "No .csproj found in src/CodeApps.Warehouse — scaffold may have failed" }
$csprojPath = $csprojFile.FullName

$csprojXml = [xml](Get-Content $csprojPath -Raw)
$propertyGroup = $csprojXml.Project.PropertyGroup | Where-Object { $_.AppName } | Select-Object -First 1
if (-not $propertyGroup) { throw "No <AppName> property found in $($csprojFile.Name)" }

# AppName drives the CanvasApp schema name (<prefix>_<appname>), the generated .meta.xml file
# name and the package folder inside the solution. Pin it so those names stay predictable
# instead of being derived from the project folder name.
$appName = "warehouseportal"
$propertyGroup.AppName = $appName

Write-Host "  ℹ CanvasApp schema name: ${PublisherPrefix}_$appName" -ForegroundColor DarkGray

# The project targets net462, so CoreCompile needs .NET Framework reference assemblies.
# Solution projects skip this (their build defines an empty CoreCompile) and plugin projects
# get the assemblies from their DevKit package — a code app project gets neither, so building
# on Linux or macOS fails with MSB3644 unless we add them explicitly.
$itemGroup = $csprojXml.CreateElement("ItemGroup")
$packageReference = $csprojXml.CreateElement("PackageReference")
$packageReference.SetAttribute("Include", "Microsoft.NETFramework.ReferenceAssemblies")
$packageReference.SetAttribute("Version", "1.0.3")
$packageReference.SetAttribute("PrivateAssets", "all")
$itemGroup.AppendChild($packageReference) | Out-Null
$csprojXml.Project.AppendChild($itemGroup) | Out-Null

$csprojXml.Save($csprojPath)

Write-Host "  ✓ $($csprojFile.Name) patched (AppName, reference assemblies)" -ForegroundColor Green

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
        --output "src/CodeApps.Warehouse" `
        --param "EntityLogicalName=$logicalName" `
        --param "ModelSolutionPath=../Solutions.DataModel"
    if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ Data source $logicalName failed" -ForegroundColor Red; exit 1 }

    Write-Host "  ✓ Data source: $logicalName" -ForegroundColor Green
}

Write-Host "  ℹ Local preview: cd src/CodeApps.Warehouse && npm run dev" -ForegroundColor DarkGray
