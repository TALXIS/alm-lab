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
# Full source: .lab-scripts/templates/13-config-data/data_schema.xml
Expand-LabTemplate -Path "13-config-data/data_schema.xml" `
    -Destination "$dataDir/data_schema.xml" `
    -Tokens @{ PREFIX = $prefix }

Write-Host "  ✓ data_schema.xml (3 entities, disableplugins)" -ForegroundColor Green

# Seed records as code. Stable GUIDs mean re-importing is an update, not a duplicate -
# the same package can run against any environment any number of times.
# Full source: .lab-scripts/templates/13-config-data/data.xml
Expand-LabTemplate -Path "13-config-data/data.xml" `
    -Destination "$dataDir/data.xml" `
    -Tokens @{ PREFIX = $prefix }

Write-Host "  ✓ data.xml (2 locations, 3 items, 2 transactions)" -ForegroundColor Green

# OPC content-types manifest — CMT packages are Open Packaging Convention archives and
# need it next to the data files.
Expand-LabTemplate -Path "13-config-data/[Content_Types].xml" `
    -Destination "$dataDir/[Content_Types].xml"

Write-Host "  ✓ [Content_Types].xml (OPC manifest)" -ForegroundColor Green
