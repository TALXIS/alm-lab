#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                          CP04: Setup runtime                                           ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Source control is our single source of truth, which lets Dev/Test environments be
# ephemeral. We create two Dataverse sandbox environments — Dev and Test — using txc.
# Their domains include your random identifier so they won't clash in the shared tenant.
#
# Sign-in uses device code: a code is shown, you open https://aka.ms/devicelogin and paste it.
#
# Run:  .lab-scripts/CP04-setup-runtime.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP04 — Runtime environments (Dev + Test)"

$rid = Initialize-RandomIdentifier

# Step 1: Device-code sign-in (browser-less). Skips if a credential already exists.
$auth = (txc config auth list --format json 2>$null | ConvertFrom-Json | Select-Object -First 1).id
if (-not $auth) {
    Write-Info "Sign in to the training tenant (device code)..."
    txc config auth login --device-code
    if ($LASTEXITCODE -ne 0) { Write-Err "Sign-in failed"; exit 1 }
    $auth = (txc config auth list --format json 2>$null | ConvertFrom-Json | Select-Object -First 1).id
    Write-Ok "Authenticated as $auth"
} else { Write-Ok "Already authenticated as $auth" }

# Step 2: Create Dev + Test sandbox environments (unique domains via $rid).
$envs = [ordered]@{ dev = "wm-dev-$rid"; test = "wm-test-$rid" }
foreach ($key in $envs.Keys) {
    $domain = $envs[$key]
    if (Get-LabValue "${key}EnvUrl") { Write-Ok "$key environment exists"; continue }
    Write-Info "Creating $key environment ($domain)..."
    txc env create --type Sandbox --name "Warehouse $key $rid" --domain $domain `
        --region europe --currency EUR --language 1033 --wait
    if ($LASTEXITCODE -ne 0) { Write-Err "Failed to create $key"; exit 1 }
    $url = "https://$domain.crm4.dynamics.com"
    Set-LabValue "${key}EnvUrl" $url
    # Bind the existing credential to a connection+profile (no extra sign-in).
    txc config connection create $key --provider Dataverse --url $url 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Err "Failed to create $key connection"; exit 1 }
    txc config profile create --name $key --auth $auth --connection $key 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Err "Failed to create $key profile"; exit 1 }
    Write-Ok "$key ready: $url"
}

# Pin the dev profile as default for local deploys.
txc config profile select dev | Out-Null
Write-Ok "Active profile: dev"

Save-Checkpoint -Id "cp04" -Message "create Dev + Test environments (rid $rid)"
Write-Host "`nNext: .lab-scripts/CP05-setup-continuous-deployment.ps1" -ForegroundColor Cyan
