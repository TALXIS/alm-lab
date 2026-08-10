#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       05d: Views and Subgrids                                          ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Creates views for all entities and subgrids on parent forms.
# Expects: $PublisherPrefix, $warehouselocationFormGuid, $warehouseitemFormGuid,
#          $warehousetransactionFormGuid from parent scope (set in 05c-forms.ps1).
#
# ──────────────────────────────────────────────────────────────────────────────────────────
#                                  Views
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Views ──" -ForegroundColor Cyan

# Helper: pp-entity-view generates a minimal lookup view (querytype=64) with only
# the primary name column. After scaffolding, we patch the XML to add
# entity-specific columns to both layoutxml and fetchxml.
function Add-ViewColumns {
    param(
        [string]$EntityDir,
        [string]$EntityLogicalName,
        [string]$PrimaryIdName,
        [string[]]$Columns  # logical names of columns to add
    )

    $prefix = $PublisherPrefix
    $viewDir = "src/Solutions.UI/Entities/${EntityLogicalName}/SavedQueries"
    if (-not (Test-Path $viewDir)) { return }

    # Find the most recently created XML (the one just scaffolded)
    $viewFile = Get-ChildItem "$viewDir/*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $viewFile) { return }

    $xml = [xml](Get-Content $viewFile.FullName -Raw)
    $row = $xml.SelectSingleNode("//row")
    $fetchEntity = $xml.SelectSingleNode("//entity")

    foreach ($col in $Columns) {
        # Add cell to layoutxml
        $cell = $xml.CreateElement("cell")
        $cell.SetAttribute("name", $col)
        $cell.SetAttribute("width", "125")
        $row.AppendChild($cell) | Out-Null

        # Add attribute to fetchxml
        $attr = $xml.CreateElement("attribute")
        $attr.SetAttribute("name", $col)
        $fetchEntity.AppendChild($attr) | Out-Null
    }

    $xml.Save($viewFile.FullName)
}

txc workspace component create pp-entity-view `
    --output "src/Solutions.UI" `
    --param "EntitySchemaName=${PublisherPrefix}_warehouselocation" `
    --param "DisplayName=Active Warehouse Locations" `
    --param "PublisherPrefix=$PublisherPrefix"

Add-ViewColumns `
    -EntityLogicalName "${PublisherPrefix}_warehouselocation" `
    -PrimaryIdName "${PublisherPrefix}_warehouselocationid" `
    -Columns @("${PublisherPrefix}_address", "${PublisherPrefix}_capacity", "${PublisherPrefix}_isactive")

# Capture the generated view GUID (filename without extension, strip braces)
$warehouselocationViewFile = Get-ChildItem "src/Solutions.UI/Entities/${PublisherPrefix}_warehouselocation/SavedQueries/*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$warehouselocationViewGuid = $warehouselocationViewFile.BaseName.Trim('{}')

Write-Host "  ✓ View: Active Warehouse Locations (with columns) — GUID: $warehouselocationViewGuid" -ForegroundColor Green

txc workspace component create pp-entity-view `
    --output "src/Solutions.UI" `
    --param "EntitySchemaName=${PublisherPrefix}_warehouseitem" `
    --param "DisplayName=Active Warehouse Items" `
    --param "PublisherPrefix=$PublisherPrefix"

Add-ViewColumns `
    -EntityLogicalName "${PublisherPrefix}_warehouseitem" `
    -PrimaryIdName "${PublisherPrefix}_warehouseitemid" `
    -Columns @("${PublisherPrefix}_sku", "${PublisherPrefix}_category", "${PublisherPrefix}_availablequantity", "${PublisherPrefix}_unitprice", "${PublisherPrefix}_locationid")

# Capture the generated view GUID
$warehouseitemViewFile = Get-ChildItem "src/Solutions.UI/Entities/${PublisherPrefix}_warehouseitem/SavedQueries/*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$warehouseitemViewGuid = $warehouseitemViewFile.BaseName.Trim('{}')

Write-Host "  ✓ View: Active Warehouse Items (with columns) — GUID: $warehouseitemViewGuid" -ForegroundColor Green

txc workspace component create pp-entity-view `
    --output "src/Solutions.UI" `
    --param "EntitySchemaName=${PublisherPrefix}_warehousetransaction" `
    --param "DisplayName=Active Warehouse Transactions" `
    --param "PublisherPrefix=$PublisherPrefix"

Add-ViewColumns `
    -EntityLogicalName "${PublisherPrefix}_warehousetransaction" `
    -PrimaryIdName "${PublisherPrefix}_warehousetransactionid" `
    -Columns @("${PublisherPrefix}_transactiontype", "${PublisherPrefix}_itemid", "${PublisherPrefix}_quantity", "${PublisherPrefix}_transactiondate", "${PublisherPrefix}_totalvalue")

# Capture the generated view GUID
$warehousetransactionViewFile = Get-ChildItem "src/Solutions.UI/Entities/${PublisherPrefix}_warehousetransaction/SavedQueries/*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$warehousetransactionViewGuid = $warehousetransactionViewFile.BaseName.Trim('{}')

Write-Host "  ✓ View: Active Warehouse Transactions (with columns) — GUID: $warehousetransactionViewGuid" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                                  Subgrids
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Subgrids ──" -ForegroundColor Cyan

# Without a RelationshipName a subgrid shows ALL records of the target entity; with it,
# only the parent's related records. The names were generated by pp-entity-attribute in
# CP06 — read them from the data model instead of hard-coding.
function Get-RelationshipName {
    param([string]$ReferencedEntity, [string]$ReferencingAttribute)
    $file = "src/Solutions.DataModel/Other/Relationships/${ReferencedEntity}.xml"
    if (-not (Test-Path $file)) { return "" }
    $xml = [xml](Get-Content $file -Raw)
    ($xml.EntityRelationships.EntityRelationship |
        Where-Object { $_.ReferencingAttributeName -eq $ReferencingAttribute } |
        Select-Object -First 1).Name
}

$locationItemsRelationship = Get-RelationshipName "${PublisherPrefix}_warehouselocation" "${PublisherPrefix}_locationid"
$itemTransactionsRelationship = Get-RelationshipName "${PublisherPrefix}_warehouseitem" "${PublisherPrefix}_itemid"
if (-not $locationItemsRelationship -or -not $itemTransactionsRelationship) {
    Write-Host "  ✗ Lookup relationships not found in Solutions.DataModel — run CP06 first" -ForegroundColor Red
    exit 1
}

# Warehouse Location form: subgrid showing related Warehouse Items
txc workspace component create pp-form-subgrid `
    --output "src/Solutions.UI" `
    --param "SubgridLabel=Warehouse Items" `
    --param "FormType=main" `
    --param "FormId=$warehouselocationFormGuid" `
    --param "TargetEntityLogicalName=${PublisherPrefix}_warehouseitem" `
    --param "EntityLogicalName=${PublisherPrefix}_warehouselocation" `
    --param "ViewId=$warehouseitemViewGuid" `
    --param "RelationshipName=$locationItemsRelationship"

Write-Host "  ✓ Subgrid: warehouselocation → Warehouse Items ($locationItemsRelationship)" -ForegroundColor Green

# Warehouse Item form: subgrid showing related Warehouse Transactions
txc workspace component create pp-form-subgrid `
    --output "src/Solutions.UI" `
    --param "SubgridLabel=Warehouse Transactions" `
    --param "FormType=main" `
    --param "FormId=$warehouseitemFormGuid" `
    --param "TargetEntityLogicalName=${PublisherPrefix}_warehousetransaction" `
    --param "EntityLogicalName=${PublisherPrefix}_warehouseitem" `
    --param "ViewId=$warehousetransactionViewGuid" `
    --param "RelationshipName=$itemTransactionsRelationship"

Write-Host "  ✓ Subgrid: warehouseitem → Warehouse Transactions ($itemTransactionsRelationship)" -ForegroundColor Green
