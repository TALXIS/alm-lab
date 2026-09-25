#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                      17: Wire Connector into Code App                                  ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Registers the connector as a code app data source. Unlike Dataverse tables (generated
# offline from Entity.xml), a connector operation has no offline generator — the typed
# model/service files are written directly here, and the live Connection + power.config.json
# binding are created via the real `pa` CLI commands below, gated behind LAB_LOCAL_MODE like
# every other live-environment step in this lab.
#
# Expects: Apps.WarehousePicking already scaffolded (CP09) and the connector deployed (step 2).
# Expects: $PublisherPrefix, and $devUrl/$devProfile (or lab state) from parent scope.
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
    if ($LASTEXITCODE -ne 0) { throw "Data source ${PublisherPrefix}_product failed" }
    # Belt-and-braces: confirm the file actually landed, not just that txc exited 0 - a silent
    # no-op here would otherwise only surface much later as a confusing TypeScript error.
    $productServicePath = "src/Apps.WarehousePicking/src/generated/services/${prefixPascal}_productsService.ts"
    if (-not (Test-Path $productServicePath)) {
        throw "pp-app-code-data reported success but $productServicePath was not written - re-run this step."
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
if ($LASTEXITCODE -ne 0) { throw "Refreshing ${PublisherPrefix}_warehouseitem data source failed" }
$warehouseitemModelPath = "src/Apps.WarehousePicking/src/generated/models/${prefixPascal}_warehouseitemsModel.ts"
if (-not ((Get-Content $warehouseitemModelPath -Raw) -match "${PublisherPrefix}_productid")) {
    throw "$warehouseitemModelPath still missing ${PublisherPrefix}_productid after refresh - re-run this step."
}

# Re-running pp-app-code-data for a table that already has a data source regenerates its
# Model/Service files correctly, but its index.ts post-action just appends - re-registering an
# existing table duplicates its two export lines rather than leaving them alone. Deduplicate
# rather than avoid the re-run entirely: index.ts is otherwise a flat list of "export ..."
# lines, so keeping only the first occurrence of each is exactly the intended fix.
$indexTsPath = "src/Apps.WarehousePicking/src/generated/index.ts"
Set-Content -Path $indexTsPath -Value (Get-Content $indexTsPath | Select-Object -Unique) -Encoding UTF8

# pp-app-code-data (templates 1.25.0) substitutes the placeholders *inside*
# services/capitalizedentitylogicalnameexamplesService.ts but never renames the file, and its
# Cleanup.ps1 only removes .template.scripts/.template.temp. The result is a second file
# declaring the same class as the correctly-named one, which breaks the TypeScript build with
# TS2308 as soon as anything globs that directory - which `pa app add data-source` does when it
# regenerates index.ts. Remove it here until the template renames it itself.
Get-ChildItem "src/Apps.WarehousePicking/src/generated/services" -Filter "capitalizedentitylogicalname*" -ErrorAction SilentlyContinue |
    ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Host "  ✓ Removed stray template file: $($_.Name)" -ForegroundColor DarkGray
    }

Write-Host "  ✓ Data source: ${PublisherPrefix}_warehouseitem (refreshed for new Product lookup)" -ForegroundColor Green

Write-Host "`n── Connector Data Source: Open Food Facts ──" -ForegroundColor Cyan

if (-not (Get-LabValue 'connectorDataSourceScaffolded')) {
    $appRoot = "src/Apps.WarehousePicking"
    $dataSourcesInfoPath = "$appRoot/.power/schemas/appschemas/dataSourcesInfo.ts"

    if (-not (Test-Path $dataSourcesInfoPath)) {
        throw "dataSourcesInfo.ts not found at $dataSourcesInfoPath - run CP09 first."
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
      },
      "GetProductImage": {
        "path": "/product-image",
        "method": "GET",
        "parameters": [
          { "name": "imageUrl", "in": "query", "required": true, "type": "string" }
        ],
        "responseInfo": {
          "200": { "type": "file" }
        }
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
        if ($closingIdx -eq -1) { throw "Could not find closing '};' in $dataSourcesInfoPath" }

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
        if ($LASTEXITCODE -ne 0) { throw "npm install @zxing/browser failed" }
    } finally { Pop-Location }
    Write-Host "  ✓ @zxing/browser installed" -ForegroundColor Green

    # The Dataverse schema name is NOT how the connectivity API addresses a connector. That API
    # validates against ^[a-zA-Z0-9\-\.]{1,64}$ - underscores are rejected outright - and custom
    # connectors are addressed by a hex-escaped id built from the *display* name plus a
    # generated suffix, e.g. shared_almlab-5fopen-20food-20facts-5f7e995f9432ef978d. That
    # suffix cannot be derived locally, so look the connector up instead of guessing its name.
    $connectorSchemaName = "${PublisherPrefix}_connectorsopenfoodfacts"
    if ($env:LAB_LOCAL_MODE) {
        Write-Info "LAB_LOCAL_MODE: skipped — would run 'pa connection create --connector"
        Write-Info "  $connectorSchemaName' then 'pa app add data-source --connector"
        Write-Info "  $connectorSchemaName --connection-id <id>' from src/Apps.WarehousePicking"
        Write-Info "  to bind a real Dev connection into power.config.json."
    } else {
        # Every `pa` call below needs the Power Platform environment id explicitly: in
        # non-interactive mode - which is how an unattended lab run executes - pa refuses with
        # "Missing required option --environment-id". Interactively it would prompt instead, so
        # this only bites the automated path. The environment id is not the Dataverse
        # organization id and is not in lab state, so resolve it from the Dev URL.
        $devEnvUrlForPa = if ($devUrl) { $devUrl } else { Get-LabValue 'devEnvUrl' }
        $devProfileForPa = if ($devProfile) { $devProfile } else { Get-LabValue 'devProfile' }
        if (-not $devEnvUrlForPa -or -not $devProfileForPa) {
            throw "Dev environment not found in lab state - run CP04 before wiring the connector into the app."
        }
        $environmentId = (txc env list --profile $devProfileForPa 2>$null | ConvertFrom-Json |
            Where-Object { $_.environmentUrl.TrimEnd('/') -eq $devEnvUrlForPa.TrimEnd('/') } |
            Select-Object -First 1).environmentId
        if (-not $environmentId) {
            throw "Could not resolve the environment id for $devEnvUrlForPa from 'txc env list'."
        }
        Write-Ok "Environment id: $environmentId"

        Push-Location $appRoot
        try {
            # Resolve the id the connectivity API actually uses. `pa` prepends "shared_" itself,
            # so hand it the name with that prefix stripped.
            Write-Info "Resolving the connector's connectivity id..."
            $connectorListJson = pa connector list --environment-id $environmentId --search "Open Food Facts" --json
            if ($LASTEXITCODE -ne 0) { throw "pa connector list failed" }
            $connectorApiName = ($connectorListJson | ConvertFrom-Json).items |
                Where-Object { $_.displayName -eq "Open Food Facts" } |
                Select-Object -First 1 -ExpandProperty name
            if (-not $connectorApiName) {
                throw "Could not find the 'Open Food Facts' connector in this environment. Deploy Solutions.Connectors (CP11 step 2) before wiring it into the app."
            }
            $connectorApiName = $connectorApiName -replace '^shared_', ''
            Write-Ok "Connector id: $connectorApiName (Dataverse schema name is $connectorSchemaName)"

            Write-Info "Creating a connection to the Open Food Facts connector..."
            $connectionJson = pa connection create --environment-id $environmentId --connector $connectorApiName --display-name "Open Food Facts" --json
            if ($LASTEXITCODE -ne 0) { throw "pa connection create failed" }
            $connectionId = ($connectionJson | ConvertFrom-Json).connectionId
            if (-not $connectionId) { throw "Could not parse connectionId from 'pa connection create' output" }
            Write-Ok "Connection created: $connectionId"

            Write-Info "Adding the connector as a data source..."
            pa app add data-source --environment-id $environmentId --connector $connectorApiName --connection-id $connectionId
            if ($LASTEXITCODE -ne 0) { throw "pa app add data-source failed" }
            Write-Ok "Connector wired into power.config.json - re-run 'npm run build' to confirm"
        } finally { Pop-Location }
    }

    Set-LabValue 'connectorDataSourceScaffolded' $true
} else {
    Write-Host "  ✓ Connector data source (exists)" -ForegroundColor Green
}
