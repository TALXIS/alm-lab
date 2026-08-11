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

# Add-ViewColumns only ever touches the lookup view (querytype=64) that
# pp-entity-view generates — it never reaches the entity's actual default
# public view (querytype=0, isdefault=1), which is what the sitemap's main
# grid renders. Without this, attendees see a nav grid with just Name +
# Created On no matter how many columns get added to the lookup view.
#
# `txc workspace component parameter list pp-entity-view` confirms the
# template has no QueryType/ViewType parameter — it can only produce a
# lookup view, full stop. So this still scaffolds via `txc` (a second,
# independent pp-entity-view call — a genuinely new component, its own
# fresh GUID, not a copy of anything), and only hand-patches the one thing
# the template has no lever for: flipping querytype 64→0 and setting
# isdefault=1 so it becomes the entity's actual default view. Dataverse
# only allows one isdefault=1 view per entity, so importing this one with
# isdefault=1 naturally un-defaults CP06's original default view — no GUID
# reuse, no collision, two genuinely separate view components.
function Add-DefaultViewColumns {
    param(
        [string]$EntityLogicalName,
        [string]$DisplayName,
        [string[]]$Columns  # logical names of columns to add
    )

    txc workspace component create pp-entity-view `
        --output "src/Solutions.UI" `
        --param "EntitySchemaName=$EntityLogicalName" `
        --param "DisplayName=$DisplayName" `
        --param "PublisherPrefix=$PublisherPrefix"

    $viewDir = "src/Solutions.UI/Entities/${EntityLogicalName}/SavedQueries"
    $viewFile = Get-ChildItem "$viewDir/*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $viewFile) { return }

    $xml = [xml](Get-Content $viewFile.FullName -Raw)
    $row = $xml.SelectSingleNode("//row")
    $fetchEntity = $xml.SelectSingleNode("//entity")

    foreach ($col in $Columns) {
        $cell = $xml.CreateElement("cell")
        $cell.SetAttribute("name", $col)
        $cell.SetAttribute("width", "125")
        $row.AppendChild($cell) | Out-Null

        $attr = $xml.CreateElement("attribute")
        $attr.SetAttribute("name", $col)
        $fetchEntity.AppendChild($attr) | Out-Null
    }

    $xml.SelectSingleNode("//querytype").InnerText = "0"
    $xml.SelectSingleNode("//isdefault").InnerText = "1"

    # pp-entity-view always appends " Lookup View" to whatever DisplayName is
    # passed, regardless of querytype — fix the label so it doesn't misname
    # what is now the entity's actual default/public view.
    $localizedName = $xml.SelectSingleNode("//LocalizedName")
    if ($localizedName) { $localizedName.SetAttribute("description", $DisplayName) }

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

# Capture the lookup view's GUID (filename without extension, strip braces) BEFORE calling
# Add-DefaultViewColumns below — that call scaffolds a second, separate view via its own
# `pp-entity-view` invocation, which becomes the "most recently created" file the moment it
# runs. Capturing after that call would silently grab the wrong (default, not lookup) view's
# GUID here, which subgrids further down use as their ViewId — wiring a subgrid to a
# querytype=0 view instead of the lookup view then triggers `txc workspace control attach`
# (Grid overlay, later in this script) to "correct" that view back to lookup-view semantics,
# reverting the column/querytype/isdefault work Add-DefaultViewColumns just did.
$warehouselocationViewFile = Get-ChildItem "src/Solutions.UI/Entities/${PublisherPrefix}_warehouselocation/SavedQueries/*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$warehouselocationViewGuid = $warehouselocationViewFile.BaseName.Trim('{}')

Write-Host "  ✓ View: Active Warehouse Locations (with columns) — GUID: $warehouselocationViewGuid" -ForegroundColor Green

Add-DefaultViewColumns `
    -EntityLogicalName "${PublisherPrefix}_warehouselocation" `
    -DisplayName "Active Warehouse Locations" `
    -Columns @("${PublisherPrefix}_address", "${PublisherPrefix}_capacity", "${PublisherPrefix}_isactive")

txc workspace component create pp-entity-view `
    --output "src/Solutions.UI" `
    --param "EntitySchemaName=${PublisherPrefix}_warehouseitem" `
    --param "DisplayName=Active Warehouse Items" `
    --param "PublisherPrefix=$PublisherPrefix"

Add-ViewColumns `
    -EntityLogicalName "${PublisherPrefix}_warehouseitem" `
    -PrimaryIdName "${PublisherPrefix}_warehouseitemid" `
    -Columns @("${PublisherPrefix}_sku", "${PublisherPrefix}_category", "${PublisherPrefix}_availablequantity", "${PublisherPrefix}_unitprice", "${PublisherPrefix}_locationid")

# Capture the lookup view's GUID BEFORE Add-DefaultViewColumns — see the comment on the
# warehouselocation capture above for why the ordering matters here.
$warehouseitemViewFile = Get-ChildItem "src/Solutions.UI/Entities/${PublisherPrefix}_warehouseitem/SavedQueries/*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$warehouseitemViewGuid = $warehouseitemViewFile.BaseName.Trim('{}')

Write-Host "  ✓ View: Active Warehouse Items (with columns) — GUID: $warehouseitemViewGuid" -ForegroundColor Green

Add-DefaultViewColumns `
    -EntityLogicalName "${PublisherPrefix}_warehouseitem" `
    -DisplayName "Active Warehouse Items" `
    -Columns @("${PublisherPrefix}_sku", "${PublisherPrefix}_category", "${PublisherPrefix}_availablequantity", "${PublisherPrefix}_unitprice", "${PublisherPrefix}_locationid")

txc workspace component create pp-entity-view `
    --output "src/Solutions.UI" `
    --param "EntitySchemaName=${PublisherPrefix}_warehousetransaction" `
    --param "DisplayName=Active Warehouse Transactions" `
    --param "PublisherPrefix=$PublisherPrefix"

Add-ViewColumns `
    -EntityLogicalName "${PublisherPrefix}_warehousetransaction" `
    -PrimaryIdName "${PublisherPrefix}_warehousetransactionid" `
    -Columns @("${PublisherPrefix}_transactiontype", "${PublisherPrefix}_itemid", "${PublisherPrefix}_quantity", "${PublisherPrefix}_transactiondate", "${PublisherPrefix}_totalvalue")

# Capture the lookup view's GUID BEFORE Add-DefaultViewColumns — see the comment on the
# warehouselocation capture above for why the ordering matters here.
$warehousetransactionViewFile = Get-ChildItem "src/Solutions.UI/Entities/${PublisherPrefix}_warehousetransaction/SavedQueries/*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$warehousetransactionViewGuid = $warehousetransactionViewFile.BaseName.Trim('{}')

Write-Host "  ✓ View: Active Warehouse Transactions (with columns) — GUID: $warehousetransactionViewGuid" -ForegroundColor Green

Add-DefaultViewColumns `
    -EntityLogicalName "${PublisherPrefix}_warehousetransaction" `
    -DisplayName "Active Warehouse Transactions" `
    -Columns @("${PublisherPrefix}_transactiontype", "${PublisherPrefix}_itemid", "${PublisherPrefix}_quantity", "${PublisherPrefix}_transactiondate", "${PublisherPrefix}_totalvalue")

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
    throw "Lookup relationships not found in Solutions.DataModel"
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
