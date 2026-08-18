#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                    CP04b: Setup runtime (Terraform)                                    ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Alternative to CP04-setup-runtime.ps1: provisions the same Dev + Test Dataverse sandbox
# environments, but declaratively via .infra/environments/terraform instead of imperative
# 'txc env create' calls. This is a paired alternative track — run CP04+CP05 (imperative) OR
# CP04b+CP05b (Terraform), not a mix. CP05b hard-fails if it can't find CP04b's Terraform
# state, so running CP04 (imperative) and then CP05b won't silently do the wrong thing.
#
# Both tracks write the identical .lab-state.json keys and leave the identical local txc
# profiles ('dev'/'test'), so CP06 onward runs completely unmodified either way. Both tracks
# also reuse the SAME checkpoint id ('cp04') as the original, so lab-status.ps1 and any
# 'git tag cp04' based rollback keep working with zero changes to either.
#
# Run:  .lab-scripts/CP04b-setup-runtime-terraform.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP04b — Runtime environments (Dev + Test) via Terraform"

$rid = Initialize-RandomIdentifier
$tfEnvDir = Join-Path $LabRoot ".infra/environments/terraform"

# Same helper CP04 uses to bind an existing txc credential to a connection by id/url without
# creating a duplicate. Duplicated here (not hoisted into Lab.Common.ps1) so this file stays
# a purely additive drop-in next to CP04, with zero changes to any existing file.
function Get-ConnectionByIdOrUrl {
    param(
        [object[]]$Connections,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url
    )
    if (-not $Connections -or $Connections.Count -eq 0) { return $null }
    return $Connections |
        Where-Object { $_.id -eq $Name -or $_.environmentUrl -eq $Url } |
        Select-Object -First 1
}

# .infra/*.tf files are scaffold-owned and intentionally left unmodified by this script, so
# there are no 'output' blocks to read devEnvUrl/devEnvId/devOrgId etc. from. Read them
# straight out of Terraform's own state instead, via 'show -json' (a stable, documented
# format) — this needs no changes to the module and works the same whether the resource was
# just created or already existed from a previous run.
function Get-TfResourceValues {
    param(
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][string]$ModuleAddress,
        [Parameter(Mandatory)][string]$ResourceAddress
    )
    $json = terraform "-chdir=$Dir" show -json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $json) { return $null }
    $state = $json | ConvertFrom-Json
    $mod = $state.values.root_module.child_modules | Where-Object { $_.address -eq $ModuleAddress }
    if (-not $mod) { return $null }
    $res = $mod.resources | Where-Object { $_.address -eq $ResourceAddress }
    if (-not $res) { return $null }
    return $res.values
}

if ($env:LAB_LOCAL_MODE) {
    Write-Info "LAB_LOCAL_MODE: skipped — would run 'terraform apply' against"
    Write-Info "  .infra/environments/terraform to provision real Dev + Test Dataverse"
    Write-Info "  sandbox environments. Stubbing devEnvUrl/testEnvUrl with unreachable"
    Write-Info "  placeholder URLs so later checkpoints that only check for their presence"
    Write-Info "  can still run."
    foreach ($key in @('dev', 'test')) {
        Set-LabValue "${key}EnvUrl" "https://local-$key.stub.invalid"
        Set-LabValue "${key}Profile" $key
    }
} else {

# Step 1: Verify Power Platform sign-in (done in CP01). Same live re-check CP04 does —
# lab-state only remembers WHICH auth profile to use, not whether it still exists here.
$auth = Get-LabValue 'txcAuth'
$liveAuth = (txc config auth list --format json 2>$null | ConvertFrom-Json | Where-Object { $_.id -eq $auth } | Select-Object -First 1)
if (-not $auth -or -not $liveAuth) {
    Write-Err "Not signed in on this machine (lab-state auth '$auth' not found locally) — run CP01 again."
    exit 1
}
Write-Ok "Authenticated as $auth"

# Step 2: terraform init — idempotent, no-op once providers are installed/cached, but the
# .terraform/ directory is gitignored (unlike .lab-state.json) so a fresh checkout or a new
# machine/session won't have it even if this checkpoint already ran elsewhere.
terraform "-chdir=$tfEnvDir" init -input=false 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Err "terraform init failed in .infra/environments/terraform"; exit 1 }

# Step 3: Apply only if we don't already have both URLs — Dataverse sandbox creation takes
# several minutes, so skip it outright once lab-state says it's done (mirrors CP04's own
# per-key skip). Once inside, Terraform's own plan/diff makes re-applying safe regardless of
# which of Dev/Test still needs creating.
#
# Caveat (shared with the rest of .infra — see its README): if this machine's local
# terraform.tfstate is missing (gitignored, doesn't travel with the repo) even though
# lab-state says devEnvUrl/testEnvUrl are already set, this will skip re-provisioning and
# nothing here can repair that on its own (it would need a manual 'terraform import', out of
# scope for the lab) — but it also won't try to create a second Dataverse environment.
$needsApply = (-not (Get-LabValue 'devEnvUrl')) -or (-not (Get-LabValue 'testEnvUrl'))
if ($needsApply) {
    Write-Info "Provisioning Dev + Test via Terraform (.infra/environments/terraform)..."
    foreach ($key in @('dev', 'test')) {
        $configPath = Join-Path $tfEnvDir "$key/config.yml"
        (Get-Content -Raw -LiteralPath $configPath) -replace '<rid>', $rid |
            Set-Content -LiteralPath $configPath -Encoding UTF8 -NoNewline
    }
    terraform "-chdir=$tfEnvDir" apply -auto-approve -input=false
    if ($LASTEXITCODE -ne 0) { Write-Err "terraform apply failed in .infra/environments/terraform"; exit 1 }
}

# Step 4: For each environment, prefer the URL lab-state already has (works even if this
# machine's local Terraform state is missing, exactly like CP04's own per-key skip); only
# fall back to reading Terraform state when lab-state doesn't have it yet — i.e. right after
# the apply above just created it. Then bind an existing txc credential to a connection +
# profile for each (no extra sign-in) — identical to CP04 from here on, since downstream
# checkpoints resolve 'dev'/'test' against txc's own local profile store, not
# .lab-state.json.
$connections = @(txc config connection list --format json | ConvertFrom-Json)
$profiles    = @(txc config profile list --format json | ConvertFrom-Json)
foreach ($key in @('dev', 'test')) {
    $url = Get-LabValue "${key}EnvUrl"
    if (-not $url) {
        $values = Get-TfResourceValues -Dir $tfEnvDir -ModuleAddress "module.$key" -ResourceAddress "module.$key.powerplatform_environment.this"
        if (-not $values) {
            Write-Err "Could not read module.$key.powerplatform_environment.this from Terraform state — did the apply above succeed?"
            exit 1
        }
        $url = $values.dataverse.url
        Set-LabValue "${key}EnvUrl" $url
        if ($values.id) { Set-LabValue "${key}EnvId" $values.id }
        if ($values.dataverse.organization_id) { Set-LabValue "${key}OrgId" $values.dataverse.organization_id }
    } else {
        Write-Ok "$key environment exists: $url"
    }

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

    Set-LabValue "${key}Profile" $key
    Write-Ok "$key ready: $url"
}

# Pin the dev profile as default for local deploys.
txc config profile select dev | Out-Null
Write-Ok "Active profile: dev"

}

Save-Checkpoint -Id "cp04" -Message "Provision Dev and Test Dataverse sandbox environments (Terraform)" -Body @'
Create dedicated Dev and Test Dataverse sandboxes so the warehouse app can be built and validated in isolated environments — declaratively, via .infra/environments/terraform, as an alternative to CP04's imperative txc calls. The script also wires local txc profiles to both environments for repeatable deployments.

## Changes
- provision Dev and Test sandbox environments with unique domains via Terraform
- create txc connections and profiles for both environments
- select the dev profile as the default local deployment target
## Testing
- terraform apply completes and txc can target the dev profile locally
'@
Write-Host "`nNext: .lab-scripts/CP05b-setup-continuous-deployment-terraform.ps1" -ForegroundColor Cyan
