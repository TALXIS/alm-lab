#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║             13: Configuration Data — CMT Package with Seed Records                     ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Creates the CMT data package in src/Packages.Main/Data: schema for the three warehouse
# tables, seed records as code, and the OPC content-types manifest.
# Expects: $PublisherPrefix from parent scope.
#
# ──────────────────────────────────────────────────────────────────────────────────────────
#                                  CMT Data Package
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── CMT Data Package ──" -ForegroundColor Cyan

$prefix  = $PublisherPrefix
$dataDir = "src/Packages.Main/Data"
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null

# Schema — plugins disabled on import so the CP07 stock plugins can't mangle seeded
# quantities while records load.
@"
<entities>
  <entity name="${prefix}_warehouselocation" displayname="Warehouse Location"
          primaryidfield="${prefix}_warehouselocationid" primarynamefield="${prefix}_name"
          disableplugins="true">
    <fields>
      <field displayname="Warehouse Location" name="${prefix}_warehouselocationid" type="guid" primaryKey="true" />
      <field displayname="Name" name="${prefix}_name" type="string" customfield="true" />
      <field displayname="Address" name="${prefix}_address" type="string" customfield="true" />
      <field displayname="Capacity" name="${prefix}_capacity" type="number" customfield="true" />
      <field displayname="Is Active" name="${prefix}_isactive" type="bool" customfield="true" />
    </fields>
  </entity>
  <entity name="${prefix}_warehouseitem" displayname="Warehouse Item"
          primaryidfield="${prefix}_warehouseitemid" primarynamefield="${prefix}_name"
          disableplugins="true">
    <fields>
      <field displayname="Warehouse Item" name="${prefix}_warehouseitemid" type="guid" primaryKey="true" />
      <field displayname="Name" name="${prefix}_name" type="string" customfield="true" />
      <field displayname="SKU" name="${prefix}_sku" type="string" customfield="true" />
      <field displayname="Available Quantity" name="${prefix}_availablequantity" type="number" customfield="true" />
      <field displayname="Category" name="${prefix}_category" type="optionsetvalue" customfield="true" />
      <field displayname="Is Perishable" name="${prefix}_isperishable" type="bool" customfield="true" />
      <field displayname="Unit Price" name="${prefix}_unitprice" type="money" customfield="true" />
      <field displayname="Reorder Point" name="${prefix}_reorderpoint" type="number" customfield="true" />
      <field displayname="Location" name="${prefix}_locationid" type="entityreference" lookupType="${prefix}_warehouselocation" customfield="true" />
    </fields>
  </entity>
  <entity name="${prefix}_warehousetransaction" displayname="Warehouse Transaction"
          primaryidfield="${prefix}_warehousetransactionid" primarynamefield="${prefix}_name"
          disableplugins="true">
    <fields>
      <field displayname="Warehouse Transaction" name="${prefix}_warehousetransactionid" type="guid" primaryKey="true" />
      <field displayname="Name" name="${prefix}_name" type="string" customfield="true" />
      <field displayname="Item" name="${prefix}_itemid" type="entityreference" lookupType="${prefix}_warehouseitem" customfield="true" />
      <field displayname="Quantity" name="${prefix}_quantity" type="number" customfield="true" />
      <field displayname="Transaction Type" name="${prefix}_transactiontype" type="optionsetvalue" customfield="true" />
      <field displayname="Reference Number" name="${prefix}_referencenumber" type="string" customfield="true" />
    </fields>
  </entity>
</entities>
"@ | Set-Content -Path "$dataDir/data_schema.xml" -Encoding UTF8

Write-Host "  ✓ data_schema.xml (3 entities, disableplugins)" -ForegroundColor Green

# Seed records as code. Stable GUIDs mean re-importing is an update, not a duplicate -
# the same package can run against any environment any number of times.
@"
<?xml version="1.0" encoding="utf-8"?>
<entities xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <entity name="${prefix}_warehouselocation" displayname="Warehouse Location">
    <records>
      <record id="2592a040-83b7-464e-ac3e-faff2031398c">
        <field name="${prefix}_warehouselocationid" value="2592a040-83b7-464e-ac3e-faff2031398c" />
        <field name="${prefix}_name" value="Main Warehouse" />
        <field name="${prefix}_address" value="123 Industrial Blvd" />
        <field name="${prefix}_capacity" value="1000" />
        <field name="${prefix}_isactive" value="True" />
      </record>
      <record id="f9c0881c-258f-42eb-b58b-84f2d37cda0e">
        <field name="${prefix}_warehouselocationid" value="f9c0881c-258f-42eb-b58b-84f2d37cda0e" />
        <field name="${prefix}_name" value="Overflow Storage" />
        <field name="${prefix}_address" value="456 Backup Lane" />
        <field name="${prefix}_capacity" value="500" />
        <field name="${prefix}_isactive" value="True" />
      </record>
    </records>
    <m2mrelationships />
  </entity>
  <entity name="${prefix}_warehouseitem" displayname="Warehouse Item">
    <records>
      <record id="6e0bd72a-0e3b-487c-b143-4c694e9e488a">
        <field name="${prefix}_warehouseitemid" value="6e0bd72a-0e3b-487c-b143-4c694e9e488a" />
        <field name="${prefix}_name" value="Office Laptop" />
        <field name="${prefix}_sku" value="LTP-001" />
        <field name="${prefix}_availablequantity" value="100" />
        <field name="${prefix}_category" value="100000000" />
        <field name="${prefix}_isperishable" value="False" />
        <field name="${prefix}_unitprice" value="899.00" />
        <field name="${prefix}_reorderpoint" value="20" />
        <field name="${prefix}_locationid" value="2592a040-83b7-464e-ac3e-faff2031398c" lookupentity="${prefix}_warehouselocation" lookupentityname="Main Warehouse" />
      </record>
      <record id="b9201d73-02eb-4065-bf4d-b5f5c5bd4b70">
        <field name="${prefix}_warehouseitemid" value="b9201d73-02eb-4065-bf4d-b5f5c5bd4b70" />
        <field name="${prefix}_name" value="Wireless Mouse" />
        <field name="${prefix}_sku" value="MSE-002" />
        <field name="${prefix}_availablequantity" value="5" />
        <field name="${prefix}_category" value="100000000" />
        <field name="${prefix}_isperishable" value="False" />
        <field name="${prefix}_unitprice" value="19.99" />
        <field name="${prefix}_reorderpoint" value="10" />
        <field name="${prefix}_locationid" value="2592a040-83b7-464e-ac3e-faff2031398c" lookupentity="${prefix}_warehouselocation" lookupentityname="Main Warehouse" />
      </record>
      <record id="e42c5c02-0cd1-4fe5-b6ef-c2c620f1bfcf">
        <field name="${prefix}_warehouseitemid" value="e42c5c02-0cd1-4fe5-b6ef-c2c620f1bfcf" />
        <field name="${prefix}_name" value="Laser Printer" />
        <field name="${prefix}_sku" value="PRN-003" />
        <field name="${prefix}_availablequantity" value="50" />
        <field name="${prefix}_category" value="100000000" />
        <field name="${prefix}_isperishable" value="False" />
        <field name="${prefix}_unitprice" value="249.50" />
        <field name="${prefix}_reorderpoint" value="15" />
        <field name="${prefix}_locationid" value="f9c0881c-258f-42eb-b58b-84f2d37cda0e" lookupentity="${prefix}_warehouselocation" lookupentityname="Overflow Storage" />
      </record>
    </records>
    <m2mrelationships />
  </entity>
  <entity name="${prefix}_warehousetransaction" displayname="Warehouse Transaction">
    <records>
      <record id="a0cdb965-1279-4f0a-a5db-58f335b9863e">
        <field name="${prefix}_warehousetransactionid" value="a0cdb965-1279-4f0a-a5db-58f335b9863e" />
        <field name="${prefix}_name" value="TRX-0001" />
        <field name="${prefix}_itemid" value="6e0bd72a-0e3b-487c-b143-4c694e9e488a" lookupentity="${prefix}_warehouseitem" lookupentityname="Office Laptop" />
        <field name="${prefix}_quantity" value="20" />
        <field name="${prefix}_transactiontype" value="100000000" />
        <field name="${prefix}_referencenumber" value="PO-2026-001" />
      </record>
      <record id="cc2d0547-3872-4f50-8db9-0cbb5407e535">
        <field name="${prefix}_warehousetransactionid" value="cc2d0547-3872-4f50-8db9-0cbb5407e535" />
        <field name="${prefix}_name" value="TRX-0002" />
        <field name="${prefix}_itemid" value="b9201d73-02eb-4065-bf4d-b5f5c5bd4b70" lookupentity="${prefix}_warehouseitem" lookupentityname="Wireless Mouse" />
        <field name="${prefix}_quantity" value="5" />
        <field name="${prefix}_transactiontype" value="100000001" />
        <field name="${prefix}_referencenumber" value="SO-2026-014" />
      </record>
    </records>
    <m2mrelationships />
  </entity>
</entities>
"@ | Set-Content -Path "$dataDir/data.xml" -Encoding UTF8

Write-Host "  ✓ data.xml (2 locations, 3 items, 2 transactions)" -ForegroundColor Green

# OPC content-types manifest — CMT packages are Open Packaging Convention archives and
# need it next to the data files. -LiteralPath because [] are wildcards in PowerShell.
@'
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="xml" ContentType="application/octet-stream"/>
</Types>
'@ | Set-Content -LiteralPath "$dataDir/[Content_Types].xml" -Encoding UTF8

Write-Host "  ✓ [Content_Types].xml (OPC manifest)" -ForegroundColor Green
