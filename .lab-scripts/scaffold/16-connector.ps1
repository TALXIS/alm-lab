#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║            16: Open Food Facts Connector — External Data Integration (Step 2)           ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Scaffolds Connectors.OpenFoodFacts (a Power Platform custom connector project) and
# Solutions.Connectors (a dedicated solution packaging it) via the pp-connector/pp-solution
# templates. The template's own placeholder apiDefinition.swagger.json/script.csx are then
# overwritten with the real Open Food Facts operation and transform logic - the template only
# knows how to scaffold a connector project's shape, not what any particular API looks like.
#
# Solutions.Connectors is deliberately its own solution, not ProjectReferenced into
# Packages.Main alongside DataModel/Logic/UI/Security - it deploys and can be tested
# independently of the rest of the app, the same way the Grid PCF control package does in
# CP10, matching what the maker portal's connector test pane already lets you do without a
# code app in the loop at all.
#
# Expects: $PublisherPrefix, $PublisherName from parent scope.
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Connectors.OpenFoodFacts ──" -ForegroundColor Cyan

if (-not (Get-LabValue 'connectorScaffolded')) {

    txc workspace component create pp-connector `
        --output "src/Connectors.OpenFoodFacts" `
        --param "Host=world.openfoodfacts.org" `
        --param "DisplayName=Open Food Facts" `
        --param "Description=Look up product data by barcode from the Open Food Facts public database." `
        --param "TransformScript=true" `
        --param "AuthType=NoAuth"

    Write-Host "  ✓ Connectors.OpenFoodFacts project" -ForegroundColor Green

    # The template scaffolds a placeholder swagger + script.csx - swap in the real Open Food
    # Facts operation (GET /product/{barcode}.json) and transform logic (User-Agent header,
    # response flattening). Full source: .lab-scripts/templates/16-connector/
    Expand-LabTemplate -Path "16-connector/apiDefinition.swagger.json" `
        -Destination "src/Connectors.OpenFoodFacts/apiDefinition.swagger.json"
    Expand-LabTemplate -Path "16-connector/script.csx" `
        -Destination "src/Connectors.OpenFoodFacts/script.csx"
    Write-Host "  ✓ apiDefinition.swagger.json + script.csx (GET /product/{barcode}.json)" -ForegroundColor Green

    # ──────────────────────────────────────────────────────────────────────────────────────
    #                                  Solutions.Connectors
    # ──────────────────────────────────────────────────────────────────────────────────────

    Write-Host "`n── Solutions.Connectors ──" -ForegroundColor Cyan

    txc workspace component create pp-solution `
        --output "src/Solutions.Connectors" `
        --param "PublisherName=$PublisherName" `
        --param "PublisherPrefix=$PublisherPrefix" `
        --param "GeneratePluginAssembly=false"

    Write-Host "  ✓ Solutions.Connectors" -ForegroundColor Green

    cd src/Solutions.Connectors
    dotnet add reference ../Connectors.OpenFoodFacts/Connectors.OpenFoodFacts.csproj
    cd ../..

    Write-Host "  ✓ ProjectReference: Connectors.OpenFoodFacts → Solutions.Connectors" -ForegroundColor Green

    Write-Host "  → Building Solutions.Connectors..." -ForegroundColor White
    cd src/Solutions.Connectors
    dotnet build --nologo --verbosity quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Solutions.Connectors build succeeded" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Solutions.Connectors build had issues (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
    }
    cd ../..

    Set-LabValue 'connectorScaffolded' $true
} else {
    Write-Host "  ✓ Connectors.OpenFoodFacts / Solutions.Connectors (exist)" -ForegroundColor Green
}
