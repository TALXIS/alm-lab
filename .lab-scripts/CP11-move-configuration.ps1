#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP11: Move configuration                                         ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Reference data (e.g. warehouse locations) must travel with the app, not be re-keyed per
# environment. The Configuration Migration Tool (CMT) via txc moves records the same way
# solutions move metadata - and just like metadata, the records themselves can be SOURCE:
# an authored data.xml with stable GUIDs that any environment imports identically.
#
# The flow, all from source control:
#   1. Author the CMT package (schema + seed records + OPC manifest) beside the Package
#      Deployer - records as code, reviewable in a PR (scaffold/13-config-data.ps1).
#   2. Import it into Dev - the app instantly has data to work with.
#   3. Round-trip: export from Dev back into the same package - any records you added
#      by hand in the maker portal get captured as source (the data twin of
#      'txc env solution pull' from CP10).
#   4. Import into Test - config stays consistent across environments; in CI the package
#      deploys alongside the solutions.
#
# Run:  .lab-scripts/CP11-move-configuration.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$PublisherPrefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP11 — Configuration data (CMT)"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/13-config-data.ps1"

    $dataDir    = Join-Path $LabRoot "src/Packages.Main/Data"
    $schemaPath = Join-Path $dataDir "data_schema.xml"
    Set-LabValue 'configDataDirectory'  $dataDir
    Set-LabValue 'configDataSchemaPath' $schemaPath
    Set-LabValue 'configDataFilePath'   (Join-Path $dataDir "data.xml")

    if ($env:LAB_LOCAL_MODE) {
        Write-Info "LAB_LOCAL_MODE: skipped — would run 'txc data pkg import' to seed Dev,"
        Write-Info "  'txc data pkg export' to round-trip Dev's data back to source, and"
        Write-Info "  'txc data pkg import' again to load it into Test. There is no live Dev/"
        Write-Info "  Test environment, so the seed data.xml scaffolded above is left as-is."
    } else {
        $devProfile  = Get-LabValue 'devProfile'
        $testProfile = Get-LabValue 'testProfile'
        if (-not $devProfile -or -not $testProfile) { Write-Err "Dev/Test profiles not found in lab state. Run CP04 first."; exit 1 }
        # Lab-state only remembers the profile NAMES — confirm they still exist in this
        # machine's own txc session (a fresh machine/Codespace won't have them even if
        # lab-state does). Wrapped in try/catch: a missing txc binary or unexpected output
        # must fall through to the clear error below, not crash with a raw PowerShell
        # exception.
        $liveProfiles = @()
        try { $liveProfiles = @(txc config profile list --format json | ConvertFrom-Json -ErrorAction Stop).id } catch { $liveProfiles = @() }
        foreach ($p in @($devProfile, $testProfile)) {
            if ($p -notin $liveProfiles) { Write-Err "txc profile '$p' not found on this machine — run CP04 again."; exit 1 }
        }

        # Step 1: Import the seed package into Dev — the app now has data.
        txc data pkg import $dataDir --profile $devProfile --allow-production
        if ($LASTEXITCODE -ne 0) { Write-Err "Seed import to Dev failed"; exit 1 }
        Write-Ok "Seed data imported to Dev"

        # Step 2: Round-trip — export Dev data back into the package. Records added by hand
        # in the maker portal get captured as source, same idea as the CP10 solution pull.
        txc data pkg export --schema $schemaPath --output $dataDir --overwrite --profile $devProfile --allow-production
        if ($LASTEXITCODE -ne 0) { Write-Err "Config export from Dev failed"; exit 1 }
        Write-Ok "Dev data exported back to source"

        # Step 3: Import into Test — config travels with the app, no re-keying per environment.
        txc data pkg import $dataDir --profile $testProfile --allow-production
        if ($LASTEXITCODE -ne 0) { Write-Err "Config import failed"; exit 1 }
        Write-Ok "Config imported to Test"

        # ──────────────────────────────────────────────────────────────────────────────────
        # Step 4: Try the code app against real data (interactive mode).
        # This is the earliest point in the lab where both the schema+plugins (CP10) and
        # meaningful seed data (this checkpoint) exist in Dev — the code app's data sources
        # only return real rows from here on. Pause and point the learner at it directly,
        # same "open it and try something" pattern as CP10's environment pause.
        # ──────────────────────────────────────────────────────────────────────────────────

        $autoMode = $env:LAB_AUTO -eq '1'
        if (-not $autoMode) {
            Write-Host ""
            Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
            Write-Host "║  Real data is seeded — try the Warehouse Picking code app live!      ║" -ForegroundColor Yellow
            Write-Host "║                                                                      ║" -ForegroundColor Yellow
            Write-Host "║    cd src/Apps.WarehousePicking && npm install && npm run dev        ║" -ForegroundColor Yellow
            Write-Host "║                                                                      ║" -ForegroundColor Yellow
            Write-Host "║  Open the printed local URL, sign in, then try:                      ║" -ForegroundColor Yellow
            Write-Host "║   1. Open Office Laptop (qty 100) and create an Outbound transaction ║" -ForegroundColor Yellow
            Write-Host "║      for a small quantity — succeeds, qty on hand updates live.      ║" -ForegroundColor Yellow
            Write-Host "║   2. Request more than 5 for Wireless Mouse (qty 5) — watch the live  ║" -ForegroundColor Yellow
            Write-Host "║      ValidateWarehouseTransactionPlugin rejection surface as a toast. ║" -ForegroundColor Yellow
            Write-Host "║                                                                      ║" -ForegroundColor Yellow
            Write-Host "║  Press ENTER when you're done trying it...                           ║" -ForegroundColor Yellow
            Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
            Write-Host ""
            Read-Host "Press ENTER to continue"
        }
    }
} finally { Pop-Location }

Save-Checkpoint -Id "cp11" -Message "Add configuration data package for environment promotion" -Body @'
Package warehouse reference data so environments stay consistent as the app moves through ALM stages. The CMT package is authored as source (seed records with stable GUIDs), imported into Dev, round-tripped back from Dev, and imported into Test.

## Changes
- add src/Packages.Main/Data/data_schema.xml covering the three warehouse tables
- add src/Packages.Main/Data/data.xml with seed locations, items, and transactions
- add the [Content_Types].xml OPC manifest required by the CMT package format
- import the package into Dev and Test; export captures manual Dev records as source
- pause after the Dev import so you can run the Warehouse Picking code app locally
  (npm run dev) against real seeded data — pick from Office Laptop (qty 100, succeeds)
  and try over-picking Wireless Mouse (qty 5, fails with the live plugin validation
  error surfaced as a toast)
## Testing
- txc data package import and export complete successfully against Dev and Test
- code app npm run dev against Dev shows real items/locations, a successful pick updates
  quantity live, and an over-pick on Wireless Mouse surfaces the plugin's rejection message
'@
Write-Host "`nNext: .lab-scripts/CP12-extend-branch-policies-build-checks.ps1" -ForegroundColor Cyan
