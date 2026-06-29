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
txc data pkg import $dataDir --profile test --allow-production
if ($LASTEXITCODE -ne 0) { Write-Err "Config import failed"; exit 1 }
Write-Ok "Config exported from Dev and imported to Test"

Save-Checkpoint -Id "cp10" -Message "configuration migration (CMT) package"
Write-Host "`nNext: .lab-scripts/CP11-extend-branch-policies-build-checks.ps1" -ForegroundColor Cyan
