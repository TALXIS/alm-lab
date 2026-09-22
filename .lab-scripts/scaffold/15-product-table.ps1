#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                              15: Product Table                                         ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Adds a Product table to Solutions.DataModel and links it to Item via a lookup column.
# Product holds externally-sourced catalog data for a barcode, separate from Item, which
# models this warehouse's own stock.
#
# No alternate key on EAN — pp-entity/pp-entity-attribute don't support scaffolding one —
# so lookups upsert in application code instead (handled where the connector is wired in).
#
# Expects: $PublisherPrefix from parent scope.
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Product table ──" -ForegroundColor Cyan

if (-not (Get-LabValue 'productTableScaffolded')) {
    txc workspace component create pp-entity `
        --output "src/Solutions.DataModel" `
        --param "EntityType=Standard" `
        --param "Behavior=New" `
        --param "PublisherPrefix=$PublisherPrefix" `
        --param "LogicalName=product" `
        --param "LogicalNamePlural=products" `
        --param "DisplayName=Product" `
        --param "DisplayNamePlural=Products"

    Write-Host "  ✓ Entity: Product" -ForegroundColor Green

    # ──────────────────────────────────────────────────────────────────────────────────────
    #                                  Product columns
    # ──────────────────────────────────────────────────────────────────────────────────────
    # The entity's own auto-created primary field (Name) holds the product's display name —
    # no separate "ProductName" column needed, same as warehouseitem/warehouselocation/
    # warehousetransaction never define one of their own either.

    txc workspace component create pp-entity-attribute `
        --output "src/Solutions.DataModel" `
        --param "EntitySchemaName=${PublisherPrefix}_product" `
        --param "AttributeType=Text" `
        --param "RequiredLevel=required" `
        --param "PublisherPrefix=$PublisherPrefix" `
        --param "LogicalName=ean" `
        --param "DisplayName=EAN"

    Write-Host "  ✓ product.ean (Text)" -ForegroundColor Green

    txc workspace component create pp-entity-attribute `
        --output "src/Solutions.DataModel" `
        --param "EntitySchemaName=${PublisherPrefix}_product" `
        --param "AttributeType=Text" `
        --param "RequiredLevel=none" `
        --param "PublisherPrefix=$PublisherPrefix" `
        --param "LogicalName=brand" `
        --param "DisplayName=Brand"

    Write-Host "  ✓ product.brand (Text)" -ForegroundColor Green

    # Open Food Facts' own "quantity" field is free text (e.g. "750g", "1L"), not a number —
    # Text, not WholeNumber/Decimal.
    txc workspace component create pp-entity-attribute `
        --output "src/Solutions.DataModel" `
        --param "EntitySchemaName=${PublisherPrefix}_product" `
        --param "AttributeType=Text" `
        --param "RequiredLevel=none" `
        --param "PublisherPrefix=$PublisherPrefix" `
        --param "LogicalName=quantity" `
        --param "DisplayName=Quantity"

    Write-Host "  ✓ product.quantity (Text)" -ForegroundColor Green

    txc workspace component create pp-entity-attribute `
        --output "src/Solutions.DataModel" `
        --param "EntitySchemaName=${PublisherPrefix}_product" `
        --param "AttributeType=Text" `
        --param "RequiredLevel=none" `
        --param "PublisherPrefix=$PublisherPrefix" `
        --param "LogicalName=imageurl" `
        --param "DisplayName=Image URL" `
        --param "TextMaxLength=500"

    # 500, not the template's 100-char default - real Open Food Facts image URLs (and most
    # CDN-hosted product images generally) routinely exceed 100 characters; the default
    # truncated real barcode scans, confirmed live (SQL "String or binary data would be
    # truncated" on almlab_imageurl when linking a real product).
    Write-Host "  ✓ product.imageurl (Text, 500 chars)" -ForegroundColor Green

    txc workspace component create pp-entity-attribute `
        --output "src/Solutions.DataModel" `
        --param "EntitySchemaName=${PublisherPrefix}_product" `
        --param "AttributeType=DateTime" `
        --param "RequiredLevel=none" `
        --param "PublisherPrefix=$PublisherPrefix" `
        --param "LogicalName=lastsyncedon" `
        --param "DisplayName=Last Synced On"

    Write-Host "  ✓ product.lastsyncedon (DateTime)" -ForegroundColor Green

    # The scanned product's photo, proxied server-side through the connector's own custom
    # code (Connectors.OpenFoodFacts/script.csx) and stored here as a real Dataverse column.
    # apps.powerapps.com's CSP (img-src 'self', no data:/blob:/external domains, confirmed
    # live) blocks the code app from rendering the raw Open Food Facts image URL directly -
    # routing the bytes through Dataverse and rendering via the SDK's same-origin download API
    # is the only fix that works under that CSP.
    #
    # File, not Image: the code app SDK's data-source generator excludes Image-type columns
    # from the generated model entirely, and its client only exposes an upload method
    # (uploadFileToRecord) for File-type columns - there is no upload counterpart for Image
    # columns, only a download one. Confirmed live: an Image-type column here never appeared
    # in the generated Product model at all. File columns support both upload and download via
    # the SDK's (undocumented-in-generated-code but public) uploadFileToRecord/
    # downloadFileFromRecord client methods.
    txc workspace component create pp-entity-attribute `
        --output "src/Solutions.DataModel" `
        --param "EntitySchemaName=${PublisherPrefix}_product" `
        --param "AttributeType=File" `
        --param "RequiredLevel=none" `
        --param "PublisherPrefix=$PublisherPrefix" `
        --param "LogicalName=productimage" `
        --param "DisplayName=Product Image"

    Write-Host "  ✓ product.productimage (File)" -ForegroundColor Green

    # ──────────────────────────────────────────────────────────────────────────────────────
    #                          Item → Product lookup
    # ──────────────────────────────────────────────────────────────────────────────────────
    # Optional: existing Item records predate Product and won't have a match until scanned.

    txc workspace component create pp-entity-attribute `
        --output "src/Solutions.DataModel" `
        --param "EntitySchemaName=${PublisherPrefix}_warehouseitem" `
        --param "AttributeType=Lookup" `
        --param "RequiredLevel=none" `
        --param "PublisherPrefix=$PublisherPrefix" `
        --param "LogicalName=productid" `
        --param "DisplayName=Product" `
        --param "LookupTarget=${PublisherPrefix}_product"

    Write-Host "  ✓ warehouseitem.productid (Lookup → product)" -ForegroundColor Green

    # Marks the whole block done — checked instead of Test-Path so a re-run after a partial
    # failure (e.g. entity created but a column create failed) retries everything rather
    # than silently skipping the missing pieces.
    Set-LabValue 'productTableScaffolded' $true
} else {
    Write-Host "  ✓ Product table (exists)" -ForegroundColor Green
}
