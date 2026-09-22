#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║        17: Wire the Open Food Facts Connector into the Code App (Step 3)               ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# `pp-app-code-data` only knows how to generate data sources for Dataverse tables (it reads
# Entity.xml straight from Solutions.DataModel - no live environment needed, which is why
# CP09's scaffold could call it for warehouseitem/warehousetransaction/warehouselocation
# without anyone being signed in yet). There is no equivalent template-side generator for a
# *connector* operation today - that's `pa app add data-source --connector`, a live-tenant
# command: it needs a real Connection (created via `pa connection create`) bound to the
# connector actually deployed in CP11 step 2, and it writes that binding into
# power.config.json, which only the Power Apps CLI is meant to touch (see
# https://learn.microsoft.com/power-apps/developer/code-apps/architecture - "Your app logic
# doesn't need to interact with the power.config.json file").
#
# So this step does the two things split by that boundary:
#   - The typed model/service/data-source-info files are static, derivable straight from the
#     connector's own already-committed swagger - written here directly, the same way
#     `pa app add data-source --connector` would, so `npm run build` is green with or
#     without a live environment. Grounded in the actual `@microsoft/power-apps` SDK types
#     (`IDataOperation.connectorOperation`) and a real generated Dataverse-table service
#     (pp-app-code-data's own output) for the surrounding shape - not guessed.
#   - Creating the live Connection and writing it into power.config.json is left to the real
#     `pa` commands below, gated behind LAB_LOCAL_MODE like every other live-environment step
#     in this lab. Run this step for real once you have a Dev environment with the connector
#     deployed (CP11 step 2) to get a working runtime binding - re-running
#     `pa app add data-source --connector` afterwards will regenerate the files below with
#     whatever the live command actually produces, which is the authoritative version.
#
# Expects: Apps.WarehousePicking already scaffolded with its 3 Dataverse data sources
# (CP09/scaffold/05f-code-app.ps1) and Connectors.OpenFoodFacts deployed (CP11 step 2).
# Expects: $PublisherPrefix from parent scope.
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Code App Data Source: Product ──" -ForegroundColor Cyan

# txc's codegen title-cases just the first character of the publisher prefix (matches
# scaffold/05f-code-app.ps1's own $prefixPascal), e.g. almlab -> Almlab_productsService.
$prefixPascal = [char]::ToUpper($PublisherPrefix[0]) + $PublisherPrefix.Substring(1)

# The Product table (CP11 step 1) needs its own typed data source in the code app, exactly
# like the 3 tables CP09 already registered - no live environment needed here either, since
# pp-app-code-data reads Entity.xml straight from Solutions.DataModel.
if (-not (Get-LabValue 'productDataSourceScaffolded')) {
    txc workspace component create pp-app-code-data `
        --output "src/Apps.WarehousePicking" `
        --param "EntityLogicalName=${PublisherPrefix}_product" `
        --param "ModelSolutionPath=../Solutions.DataModel"
    if ($LASTEXITCODE -ne 0) { Write-Err "Data source ${PublisherPrefix}_product failed"; exit 1 }
    # Belt-and-braces: confirm the file actually landed, not just that txc exited 0 - a silent
    # no-op here would otherwise only surface much later as a confusing TypeScript error.
    $productServicePath = "src/Apps.WarehousePicking/src/generated/services/${prefixPascal}_productsService.ts"
    if (-not (Test-Path $productServicePath)) {
        Write-Err "pp-app-code-data reported success but $productServicePath was not written - re-run this step."
        exit 1
    }
    Write-Host "  ✓ Data source: ${PublisherPrefix}_product" -ForegroundColor Green
    Set-LabValue 'productDataSourceScaffolded' $true
} else {
    Write-Host "  ✓ Data source: ${PublisherPrefix}_product (exists)" -ForegroundColor Green
}

# CP11 step 1 added a Product lookup column to warehouseitem *after* CP09 first generated its
# data source - re-run pp-app-code-data for it too, so the stale model picks up the new
# productid field. Re-running for a table that already has a data source just regenerates its
# Model/Service files fresh from the entity's current Entity.xml; idempotent either way.
txc workspace component create pp-app-code-data `
    --output "src/Apps.WarehousePicking" `
    --param "EntityLogicalName=${PublisherPrefix}_warehouseitem" `
    --param "ModelSolutionPath=../Solutions.DataModel"
if ($LASTEXITCODE -ne 0) { Write-Err "Refreshing ${PublisherPrefix}_warehouseitem data source failed"; exit 1 }
$warehouseitemModelPath = "src/Apps.WarehousePicking/src/generated/models/${prefixPascal}_warehouseitemsModel.ts"
if (-not ((Get-Content $warehouseitemModelPath -Raw) -match "${PublisherPrefix}_productid")) {
    Write-Err "$warehouseitemModelPath still missing ${PublisherPrefix}_productid after refresh - re-run this step."
    exit 1
}

# Re-running pp-app-code-data for a table that already has a data source regenerates its
# Model/Service files correctly, but its index.ts post-action just appends - re-registering an
# existing table duplicates its two export lines rather than leaving them alone. Deduplicate
# rather than avoid the re-run entirely: index.ts is otherwise a flat list of "export ..."
# lines, so keeping only the first occurrence of each is exactly the intended fix.
$indexTsPath = "src/Apps.WarehousePicking/src/generated/index.ts"
Set-Content -Path $indexTsPath -Value (Get-Content $indexTsPath | Select-Object -Unique) -Encoding UTF8

Write-Host "  ✓ Data source: ${PublisherPrefix}_warehouseitem (refreshed for new Product lookup)" -ForegroundColor Green

Write-Host "`n── Connector Data Source: Open Food Facts ──" -ForegroundColor Cyan

if (-not (Get-LabValue 'connectorDataSourceScaffolded')) {
    $appRoot = "src/Apps.WarehousePicking"
    $dataSourcesInfoPath = "$appRoot/.power/schemas/appschemas/dataSourcesInfo.ts"

    if (-not (Test-Path $dataSourcesInfoPath)) {
        Write-Err "dataSourcesInfo.ts not found at $dataSourcesInfoPath - run CP09 first."
        exit 1
    }

    $newEntry = @'
  "OpenFoodFacts": {
    "tableId": "",
    "version": "",
    "dataSourceType": "Connector",
    "apis": {
      "GetProductByBarcode": {
        "path": "/product/{barcode}.json",
        "method": "GET",
        "parameters": [
          { "name": "barcode", "in": "path", "required": true, "type": "string" }
        ]
      }
    }
  }
'@

    $text = [System.IO.File]::ReadAllText($dataSourcesInfoPath)
    if ($text.Contains('"OpenFoodFacts"')) {
        Write-Host "  ✓ dataSourcesInfo.ts (OpenFoodFacts entry exists)" -ForegroundColor Green
    } else {
        # Same insertion approach pp-app-code-data's own AddDataSourceInfo.ps1 uses: find the
        # object literal's closing '};', insert the new entry right before it (after a comma
        # on the previous entry's closing '}', if there is one).
        $lines = [System.IO.File]::ReadAllLines($dataSourcesInfoPath)
        $result = [System.Collections.Generic.List[string]]::new()

        $closingIdx = -1
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            if ($lines[$i].TrimStart() -eq '};') { $closingIdx = $i; break }
        }
        if ($closingIdx -eq -1) { Write-Err "Could not find closing '};' in $dataSourcesInfoPath"; exit 1 }

        $lastEntryClose = -1
        for ($i = $closingIdx - 1; $i -ge 0; $i--) {
            if ($lines[$i].TrimStart() -eq '}' -or $lines[$i].TrimStart() -eq '},') { $lastEntryClose = $i; break }
        }

        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -eq $lastEntryClose -and $lastEntryClose -ne -1) {
                $line = $lines[$i].TrimEnd()
                if (-not $line.EndsWith(',')) { $line += ',' }
                $result.Add($line)
                foreach ($entryLine in $newEntry.Split("`n")) { $result.Add($entryLine.TrimEnd("`r")) }
            } elseif ($i -eq $closingIdx -and $lastEntryClose -eq -1) {
                foreach ($entryLine in $newEntry.Split("`n")) { $result.Add($entryLine.TrimEnd("`r")) }
                $result.Add($lines[$i])
            } else {
                $result.Add($lines[$i])
            }
        }
        [System.IO.File]::WriteAllLines($dataSourcesInfoPath, $result)
        Write-Host "  ✓ dataSourcesInfo.ts (added OpenFoodFacts entry)" -ForegroundColor Green
    }

    Expand-LabTemplate -Path "17-connector-datasource/OpenFoodFactsModel.ts" `
        -Destination "$appRoot/src/generated/models/OpenFoodFactsModel.ts"
    Expand-LabTemplate -Path "17-connector-datasource/OpenFoodFactsService.ts" `
        -Destination "$appRoot/src/generated/services/OpenFoodFactsService.ts"
    Write-Host "  ✓ OpenFoodFactsModel.ts + OpenFoodFactsService.ts" -ForegroundColor Green

    Write-Host "  → Installing @zxing/browser (camera barcode decoding)..." -ForegroundColor White
    Push-Location $appRoot
    try {
        npm install @zxing/browser --save --silent
        if ($LASTEXITCODE -ne 0) { Write-Err "npm install @zxing/browser failed"; exit 1 }
    } finally { Pop-Location }
    Write-Host "  ✓ @zxing/browser installed" -ForegroundColor Green

    if ($env:LAB_LOCAL_MODE) {
        Write-Info "LAB_LOCAL_MODE: skipped — would run 'pa connection create --connector"
        Write-Info "  almlab_connectorsopenfoodfacts' then 'pa app add data-source --connector"
        Write-Info "  almlab_connectorsopenfoodfacts --connection-id <id>' from src/Apps.WarehousePicking"
        Write-Info "  to bind a real Dev connection into power.config.json."
    } else {
        Push-Location $appRoot
        try {
            Write-Info "Creating a connection to the Open Food Facts connector..."
            $connectionJson = pa connection create --connector "almlab_connectorsopenfoodfacts" --display-name "Open Food Facts" --json
            if ($LASTEXITCODE -ne 0) { Write-Err "pa connection create failed"; exit 1 }
            $connectionId = ($connectionJson | ConvertFrom-Json).connectionId
            if (-not $connectionId) { Write-Err "Could not parse connectionId from 'pa connection create' output"; exit 1 }
            Write-Ok "Connection created: $connectionId"

            Write-Info "Adding the connector as a data source..."
            pa app add data-source --connector "almlab_connectorsopenfoodfacts" --connection-id $connectionId
            if ($LASTEXITCODE -ne 0) { Write-Err "pa app add data-source failed"; exit 1 }
            Write-Ok "Connector wired into power.config.json - re-run 'npm run build' to confirm"
        } finally { Pop-Location }
    }

    Set-LabValue 'connectorDataSourceScaffolded' $true
} else {
    Write-Host "  ✓ Connector data source (exists)" -ForegroundColor Green
}
