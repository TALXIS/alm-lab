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

function Get-ConnectionByIdOrUrl {
    param(
        [Parameter(Mandatory)][object[]]$Connections,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url
    )

    return $Connections |
        Where-Object { $_.id -eq $Name -or $_.environmentUrl -eq $Url } |
        Select-Object -First 1
}

# Step 1: Verify Power Platform sign-in (done in CP01).
$auth = Get-LabValue 'txcAuth'
if (-not $auth) { Write-Err "Not signed in — run CP01 first"; exit 1 }
Write-Ok "Authenticated as $auth"

# Step 2: Create Dev + Test sandbox environments (unique domains via $rid).
$envs = [ordered]@{ dev = "wm-dev-$rid"; test = "wm-test-$rid" }
$connections = @(txc config connection list --format json | ConvertFrom-Json)
$profiles    = @(txc config profile list --format json | ConvertFrom-Json)
foreach ($key in $envs.Keys) {
    $domain = $envs[$key]
    $displayName = "Warehouse $key $rid"
    $url = Get-LabValue "${key}EnvUrl"
    if (-not $url) {
        Write-Info "Creating $key environment ($domain)..."
        txc env create --type Sandbox --name $displayName --domain $domain `
            --region europe --currency EUR --language 1033 --wait
        if ($LASTEXITCODE -ne 0) { Write-Err "Failed to create $key"; exit 1 }
        $url = "https://$domain.crm4.dynamics.com"
    } else {
        Write-Ok "$key environment exists: $url"
    }

    Set-LabValue "${key}EnvName"   $displayName
    Set-LabValue "${key}EnvDomain" $domain
    Set-LabValue "${key}EnvUrl" $url

    # Bind the existing credential to a connection+profile (no extra sign-in).
    $connection = Get-ConnectionByIdOrUrl -Connections $connections -Name $key -Url $url
    if (-not $connection) {
        txc config connection create $key --provider Dataverse --url $url 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Err "Failed to create $key connection"; exit 1 }
        $connections = @(txc config connection list --format json | ConvertFrom-Json)
        $connection = Get-ConnectionByIdOrUrl -Connections $connections -Name $key -Url $url
    } else {
        Write-Ok "$key connection exists"
    }

    if (-not ($profiles | Where-Object { $_.id -eq $key })) {
        txc config profile create --name $key --auth $auth --connection $key 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Err "Failed to create $key profile"; exit 1 }
        $profiles = @(txc config profile list --format json | ConvertFrom-Json)
    } else {
        Write-Ok "$key profile exists"
    }

    if ($connection.environmentId) { Set-LabValue "${key}EnvId" $connection.environmentId }
    if ($connection.organizationId) { Set-LabValue "${key}OrgId" $connection.organizationId }
    Set-LabValue "${key}Profile" $key
    Write-Ok "$key ready: $url"
}

# Pin the dev profile as default for local deploys.
txc config profile select dev | Out-Null
Write-Ok "Active profile: dev"

Save-Checkpoint -Id "cp04" -Message "Provision Dev and Test Dataverse sandbox environments" -Body @'
Create dedicated Dev and Test Dataverse sandboxes so the warehouse app can be built and validated in isolated environments. The script also wires local txc profiles to both environments for repeatable deployments.

## Changes
- provision Dev and Test sandbox environments with unique domains
- create txc connections and profiles for both environments
- select the dev profile as the default local deployment target
## Testing
- environment provisioning completes and txc can target the dev profile locally
'@
Write-Host "`nNext: .lab-scripts/CP05-setup-continuous-deployment.ps1" -ForegroundColor Cyan
