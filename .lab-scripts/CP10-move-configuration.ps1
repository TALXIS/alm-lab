#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP10: Move configuration                                         ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Reference data (e.g. warehouse locations) must travel with the app, not be re-keyed per
# environment. We use the Configuration Migration Tool (CMT) via txc: export config data
# from Dev, store the package next to the Package Deployer, and import into Test. In CI the
# package is deployed alongside solutions, keeping config in source control too.
#
# Run:  .lab-scripts/CP10-move-configuration.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$prefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP10 — Configuration data (CMT)"
$dataDir = Join-Path $LabRoot "src/Packages.Main/Data"
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
Set-LabValue 'configDataDirectory'  $dataDir
Set-LabValue 'configDataSchemaPath' (Join-Path $dataDir "data_schema.xml")

# CMT schema: warehouse locations are reference/config data (plugins disabled on import).
@"
<entities>
  <entity name="${prefix}_warehouselocation" displayname="Warehouse Location"
          primaryidfield="${prefix}_warehouselocationid" primarynamefield="${prefix}_name"
          disableplugins="true">
    <fields>
      <field displayname="Name" name="${prefix}_name" type="string" primaryKey="false" />
    </fields>
  </entity>
</entities>
"@ | Set-Content -Path (Join-Path $dataDir "data_schema.xml") -Encoding UTF8

# Export from Dev, import to Test.
# Export from Dev, import to Test. Export needs --schema + --output; import takes the folder.
txc data pkg export --schema (Join-Path $dataDir "data_schema.xml") --output $dataDir --overwrite --profile dev --allow-production
if (-not (Test-Path (Join-Path $dataDir "data.xml"))) {
    Write-Warn2 "No config records in Dev yet — add a few Warehouse Locations, then re-run CP10."
    exit 1
}
Set-LabValue 'configDataFilePath' (Join-Path $dataDir "data.xml")
txc data pkg import $dataDir --profile test --allow-production
if ($LASTEXITCODE -ne 0) { Write-Err "Config import failed"; exit 1 }
Set-LabValue 'configImportedToUrl' (Get-LabValue 'testEnvUrl')
Write-Ok "Config exported from Dev and imported to Test"

Save-Checkpoint -Id "cp10" -Message "Add configuration data package for environment promotion" -Body @'
Package warehouse reference data so environments stay consistent as the app moves through ALM stages. This stores the configuration migration assets beside the deployer and moves the exported data into Test.

## Changes
- add src/Packages.Main/Data/data_schema.xml for warehouse location config data
- export configuration data from Dev into the package data folder
- import the packaged configuration data into the Test environment
## Testing
- txc data package export and import complete successfully between Dev and Test
'@
Write-Host "`nNext: .lab-scripts/CP11-extend-branch-policies-build-checks.ps1" -ForegroundColor Cyan
