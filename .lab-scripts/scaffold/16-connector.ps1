#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                            16: Custom Connector                                        ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Scaffolds Connectors.OpenFoodFacts (a custom connector project) and Solutions.Connectors
# (a dedicated solution packaging it) via the pp-connector/pp-solution templates, then fills
# in the operation and transform logic for this connector's own API.
#
# Solutions.Connectors is its own solution rather than ProjectReferenced into Packages.Main,
# so it deploys and can be tested independently of the rest of the app — same as the Grid
# PCF control package in CP10.
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
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path "src/Connectors.OpenFoodFacts/Connectors.OpenFoodFacts.csproj")) {
        Write-Err "Connectors.OpenFoodFacts scaffold failed - re-run this step."
        exit 1
    }

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
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path "src/Solutions.Connectors/Solutions.Connectors.csproj")) {
        Write-Err "Solutions.Connectors scaffold failed - re-run this step."
        exit 1
    }

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
