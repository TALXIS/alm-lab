#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║              14: Unit Tests — Plugin (FakeXrmEasy) and Script (Jest) Projects          ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Creates Tests.Plugins (FakeXrmEasy in-memory Dataverse) and Tests.Scripts (Jest with a
# mocked Xrm) with tests adapted to the warehouse plugins and form scripts.
# Expects: $PublisherPrefix from parent scope.
#
# ──────────────────────────────────────────────────────────────────────────────────────────
#                                    Tests.Plugins
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Tests.Plugins ──" -ForegroundColor Cyan

$prefix = $PublisherPrefix

if (-not (Get-LabValue 'pluginsTestsScaffolded')) {

# The pp-plugin-test template's Cleanup post-action expects .template.temp to exist and
# fails (rolling everything back) when it doesn't - pre-create it as a workaround.
New-Item -ItemType Directory -Path "src/Tests.Plugins/.template.temp" -Force | Out-Null

txc workspace component create pp-plugin-test `
    --output "src/Tests.Plugins"

dotnet sln add src/Tests.Plugins

cd src/Tests.Plugins
# Tests.Plugins targets net10.0 (FakeXrmEasy v3) but Plugins.Warehouse targets net462 -
# the Dataverse plugin sandbox is still .NET Framework, so that side can't move (see the
# constraint note near the top of CP14-implement-unit-tests.ps1). `dotnet add reference`
# refuses to link projects across that gap: it runs its own net10.0-vs-net462 compatibility
# preflight and there is no bypass flag, not even `-f`/`--framework` (checked). The actual
# build doesn't share that limitation - NuGet's asset target fallback resolves the net462
# reference fine, which is why `dotnet build`/`dotnet test` further down print a NU1702
# warning ("resolved using .NETFramework,Version=v4.7.2 instead of..."). That warning is
# expected and benign here - don't "fix" it by trying to retarget either project. So skip
# the CLI and add the <ProjectReference> element to the csproj XML directly instead.
$testCsproj = "Tests.Plugins.csproj"
[xml]$csprojXml = Get-Content $testCsproj -Raw
$namespaceUri = $csprojXml.DocumentElement.NamespaceURI
$itemGroup = $csprojXml.CreateElement("ItemGroup", $namespaceUri)
$projectReference = $csprojXml.CreateElement("ProjectReference", $namespaceUri)
$projectReference.SetAttribute("Include", "../Plugins.Warehouse/Plugins.Warehouse.csproj")
$itemGroup.AppendChild($projectReference) | Out-Null
$csprojXml.Project.AppendChild($itemGroup) | Out-Null
$csprojXml.Save((Resolve-Path $testCsproj))
cd ../..

Write-Host "  ✓ Tests.Plugins project (FakeXrmEasy)" -ForegroundColor Green

# Tests adapted to OUR plugins: both require ${prefix}_transactiontype in the Target,
# validation only guards Outbound (100000001), and Inbound (100000000) adds stock.
# Full source: .lab-scripts/templates/14-tests-unit/ValidateWarehouseTransactionPluginTests.cs
Expand-LabTemplate -Path "14-tests-unit/ValidateWarehouseTransactionPluginTests.cs" `
    -Destination "src/Tests.Plugins/ValidateWarehouseTransactionPluginTests.cs" `
    -Tokens @{ PREFIX = $prefix }
Write-Host "  ✓ ValidateWarehouseTransactionPluginTests.cs" -ForegroundColor Green

# Full source: .lab-scripts/templates/14-tests-unit/SubtractQuantityPluginTests.cs
Expand-LabTemplate -Path "14-tests-unit/SubtractQuantityPluginTests.cs" `
    -Destination "src/Tests.Plugins/SubtractQuantityPluginTests.cs" `
    -Tokens @{ PREFIX = $prefix }
Write-Host "  ✓ SubtractQuantityPluginTests.cs" -ForegroundColor Green

# Marks the block done — checked instead of Test-Path on the csproj so a re-run after a
# partial failure (e.g. project created but the csproj XML patch or test files didn't
# finish) retries everything rather than silently skipping the missing work.
Set-LabValue 'pluginsTestsScaffolded' $true

} else {
    Write-Host "  ✓ Plugins.Tests (exists)" -ForegroundColor Green
}

# ──────────────────────────────────────────────────────────────────────────────────────────
#                                    Tests.Scripts
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Tests.Scripts ──" -ForegroundColor Cyan

if (-not (Get-LabValue 'scriptsTestsScaffolded')) {

# ScriptLibraryPath points at the rollup bundle Scripts.UI builds - the same file that
# ships as the web resource is the file under test.
txc workspace component create pp-test-script `
    --output "src/Tests.Scripts" `
    --param "ScriptTestProjectName=Tests.Scripts" `
    --param "ScriptLibraryPath=../Scripts.UI/build/${prefix}_main.js"

dotnet sln add src/Tests.Scripts

Write-Host "  ✓ Tests.Scripts project (Jest)" -ForegroundColor Green

# Jest 30 does not expose global.jest to the template's setupXrm, so the Xrm functions a
# test relies on are assigned as jest.fn() explicitly in beforeEach (same as dev-loops CFN).
# Full source: .lab-scripts/templates/14-tests-unit/transactionForm.test.js
Expand-LabTemplate -Path "14-tests-unit/transactionForm.test.js" `
    -Destination "src/Tests.Scripts/tests/transactionForm.test.js" `
    -Tokens @{ PREFIX = $prefix }
Write-Host "  ✓ tests/transactionForm.test.js" -ForegroundColor Green

# Full source: .lab-scripts/templates/14-tests-unit/ribbonActions.test.js
Expand-LabTemplate -Path "14-tests-unit/ribbonActions.test.js" `
    -Destination "src/Tests.Scripts/tests/ribbonActions.test.js" `
    -Tokens @{ PREFIX = $prefix }
Write-Host "  ✓ tests/ribbonActions.test.js" -ForegroundColor Green

# Marks the block done — checked instead of Test-Path on the project directory so a re-run
# after a partial failure retries everything rather than silently skipping missing work.
Set-LabValue 'scriptsTestsScaffolded' $true

} else {
    Write-Host "  ✓ Scripts.Tests (exists)" -ForegroundColor Green
}
