#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║              CP05b: Setup Continuous Deployment (Terraform)                            ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Alternative to CP05-setup-continuous-deployment.ps1: creates the same OIDC deployment
# identity and Test application-user registration, but declaratively — via
# infra/identity/terraform (app registration + service principal + federated credential)
# and infra/environments/terraform/test's app-user.tf (Dataverse systemuser + System
# Administrator role) — instead of 'az ad app create' and raw Dataverse OData calls.
#
# This only works if CP04b (not CP04) ran first: re-applying infra/environments/terraform
# to add the Test app-user requires Terraform's own local state to already own
# module.test.powerplatform_environment.this. We check for that explicitly below and fail
# fast with a clear message rather than risk Terraform trying to create a second Test
# environment because it doesn't recognize the one CP04 (imperative) made by hand.
#
# Run:  .lab-scripts/CP05b-setup-continuous-deployment-terraform.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP05b — Continuous Deployment (OIDC, Terraform)"

$rid           = Initialize-RandomIdentifier
$repo          = Get-LabValue 'repo'
$testUrl       = Get-LabValue 'testEnvUrl'
$tfEnvDir      = Join-Path $LabRoot "infra/environments/terraform"
$tfIdentityDir = Join-Path $LabRoot "infra/identity/terraform"

if (-not $repo -and -not $env:LAB_LOCAL_MODE) { $originUrl = git -C $LabRoot remote get-url origin 2>$null; if ($originUrl -match 'github\.com[:/](.+?)(?:\.git)?$') { $repo = $Matches[1] }; Set-LabValue 'repo' $repo }
if (-not $testUrl) { Write-Err "Run CP04b first (Test environment URL missing). If you ran CP04 (imperative) instead, use CP05-setup-continuous-deployment.ps1, not this script."; exit 1 }

if ($env:LAB_LOCAL_MODE) {
    Write-Info "LAB_LOCAL_MODE: skipped — would verify Azure sign-in, apply"
    Write-Info "  infra/identity/terraform to create an Entra app registration + service"
    Write-Info "  principal + federated credential trusting this repo's main branch, and"
    Write-Info "  re-apply infra/environments/terraform to add the SP as a System"
    Write-Info "  Administrator application user in the Test environment."
    $tenantId = Get-LabValue 'tenantId'; if (-not $tenantId) { $tenantId = "00000000-0000-0000-0000-000000000000"; Set-LabValue 'tenantId' $tenantId }
    $appId = Get-LabValue 'appId'; if (-not $appId) { $appId = "00000000-0000-0000-0000-000000000000"; Set-LabValue 'appId' $appId }
} else {

# Step 0: Confirm CP04b's Terraform state actually owns the Test environment. Without this,
# a Test environment created imperatively by CP04 (or a local .terraform.tfstate lost to a
# fresh checkout/new machine — it's gitignored, unlike .lab-state.json — see infra/README.md)
# would make Terraform think module.test.powerplatform_environment.this doesn't exist yet,
# and try to create a second Test environment instead of adding an app-user to the one that's
# actually there.
terraform "-chdir=$tfEnvDir" init -input=false 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Err "terraform init failed in infra/environments/terraform"; exit 1 }
terraform "-chdir=$tfEnvDir" state list module.test.powerplatform_environment.this 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Err "module.test.powerplatform_environment.this not found in infra/environments/terraform's local state."
    Write-Err "Run CP04b-setup-runtime-terraform.ps1 first. If you already ran it on a different machine or"
    Write-Err "session, its local Terraform state file didn't travel with the repo (gitignored by design) — see"
    Write-Err "'Local state only' in infra/README.md; you'll need to re-run CP04b there, or 'terraform import'"
    Write-Err "the existing environment into state by hand."
    exit 1
}
Write-Ok "Terraform owns module.test.powerplatform_environment.this"

# Step 1: Verify Azure sign-in and tenant (done in CP01). Terraform's azuread provider reads
# this same 'az' CLI session (provider "azuread" {} defaults to Azure CLI auth) — no separate
# sign-in needed for the apply below.
$tenantId = Get-LabValue 'tenantId'
if (-not $tenantId) {
    $tenantId = az account show --query tenantId -o tsv 2>$null
    if (-not $tenantId) { Write-Err "Not signed in to Azure — run CP01 first"; exit 1 }
    Set-LabValue 'tenantId' $tenantId
}
Write-Ok "Azure: tenant $tenantId"

# Step 2+3: App registration, service principal, and federated credential — all three are
# one Terraform resource graph in infra/identity/terraform, applied in a single call.
# Unlike CP05's hand-rolled "skip if appId already looks valid" check, we apply every time:
# it's 1 app + 1 SP + 1 federated credential, Terraform's plan/diff is what makes this cheap
# and safe to repeat, and — unlike CP05's shortcut — it also self-heals if the federated
# credential (or SP) was deleted out-of-band while the app registration itself survived.
#
# Known limitation (documented, not engineered around — same class of risk as the local
# Terraform state caveats in infra/README.md): if this machine's local Terraform state for
# identity/terraform is lost while lab-state's appId still points at a real app, this apply
# will create a SECOND Entra app registration with the same display name — Azure AD (unlike
# Dataverse) does not enforce display-name uniqueness, so this fails silently rather than
# loudly. The new appId still gets written to lab-state and GitHub secrets correctly below;
# the old app registration is just orphaned. Fixing this would need a live
# 'az ad app list --display-name' pre-check plus 'terraform import', out of scope here.
terraform "-chdir=$tfIdentityDir" init -input=false 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Err "terraform init failed in infra/identity/terraform"; exit 1 }
$appName = "wm-deploy-$rid"
terraform "-chdir=$tfIdentityDir" apply -auto-approve -input=false `
    -var "app_display_name=$appName" `
    -var "github_repo=$repo"
if ($LASTEXITCODE -ne 0) { Write-Err "terraform apply failed in infra/identity/terraform"; exit 1 }

$identityOutputJson = terraform "-chdir=$tfIdentityDir" output -json
if ($LASTEXITCODE -ne 0 -or -not $identityOutputJson) { Write-Err "Could not read terraform output from infra/identity/terraform"; exit 1 }
$appId = ($identityOutputJson | ConvertFrom-Json).client_id.value
if (-not $appId) { Write-Err "identity/terraform apply succeeded but produced no client_id output"; exit 1 }
Set-LabValue 'appId' $appId
Write-Ok "App registration: $appName ($appId)"
Write-Ok "Federated credential (repo:${repo}:ref:refs/heads/main)"

# Step 4: Add SP as application user with System Administrator role in Test env — this is
# infra/environments/terraform/test/app-user.tf, gated on deployment_principal_id being
# non-empty in test/config.yml. Point it at the app id we just created, then re-apply the
# whole environments/terraform root (dev + test together — that's how the module is
# composed). This only ever touches Test: dev/config.yml's deployment_principal_id is left
# alone ("" by default), so dev/app-user.tf's count stays 0.
#
# NOTE: System Administrator keeps the lab simple but breaks the least-privilege rule we
# apply to users in CP08. In production, give the deploy principal a custom role scoped to
# what imports actually need, and never a tenant-level Power Platform admin role.
$testConfigPath = Join-Path $tfEnvDir "test/config.yml"
$replacement = "deployment_principal_id: `"$appId`""
(Get-Content -Raw -LiteralPath $testConfigPath) -replace 'deployment_principal_id:.*', $replacement |
    Set-Content -LiteralPath $testConfigPath -Encoding UTF8 -NoNewline

terraform "-chdir=$tfEnvDir" apply -auto-approve -input=false
if ($LASTEXITCODE -ne 0) { Write-Err "terraform apply failed in infra/environments/terraform (Test app-user)"; exit 1 }
Write-Ok "Service principal added to Test environment as application user (System Administrator)"

}

# Step 5: GitHub secrets.
if ($env:LAB_LOCAL_MODE) {
    Write-Info "LAB_LOCAL_MODE: skipped — would run 'gh secret set AZURE_CLIENT_ID/AZURE_TENANT_ID/DATAVERSE_TEST_URL'"
} else {
    gh secret set AZURE_CLIENT_ID    --repo $repo --body $appId
    gh secret set AZURE_TENANT_ID    --repo $repo --body $tenantId
    gh secret set DATAVERSE_TEST_URL --repo $repo --body $testUrl
    Write-Ok "Secrets set: AZURE_CLIENT_ID, AZURE_TENANT_ID, DATAVERSE_TEST_URL"
}

# Step 6: Enable GitHub Actions on the fork (forks have them disabled by default).
if ($env:LAB_LOCAL_MODE) {
    Write-Info "LAB_LOCAL_MODE: skipped — would run 'gh api -X PUT repos/<repo>/actions/permissions'"
} else {
    gh api -X PUT "repos/$repo/actions/permissions" -F enabled=true -f allowed_actions=all 2>&1 | Out-Null
    Write-Ok "GitHub Actions enabled on the fork"
}

# Step 7: Install workflows. Pushing files under .github/workflows needs the 'workflow'
# scope. Same build.yml/deploy.yml as CP05 — how CP04b/CP05b provisioned the environments
# and identity is invisible to the workflow files themselves, which only need
# AZURE_CLIENT_ID/AZURE_TENANT_ID/DATAVERSE_TEST_URL. Runs unconditionally, even under
# LAB_LOCAL_MODE (only the 'gh auth refresh' scope grant right below is LOCAL_MODE-gated) —
# matching CP05's own asymmetry, so the local dry-run harness's CP05 → CP05b interleaving
# stays a harmless no-op (same source files copied twice).
if (-not $env:LAB_LOCAL_MODE -and -not ((gh auth status 2>&1) -match 'workflow')) {
    Write-Info "Granting GitHub CLI the 'workflow' scope (needed to push Actions)..."
    gh auth refresh -h github.com -s workflow
}
$wf = Join-Path $LabRoot ".github/workflows"
New-Item -ItemType Directory -Path $wf -Force | Out-Null
Copy-Item "$PSScriptRoot/workflows/build.yml"  $wf -Force
Copy-Item "$PSScriptRoot/workflows/deploy.yml" $wf -Force
Write-Ok "Installed build.yml + deploy.yml"

Save-Checkpoint -Id "cp05" -Message "Configure OIDC deployment identity and GitHub workflows (Terraform)" -Body @'
Set up GitHub Actions deployment for the warehouse app without long-lived secrets — declaratively, via infra/identity/terraform and infra/environments/terraform/test's app-user.tf, as an alternative to CP05's imperative az/REST calls. This adds an Entra application identity, federated trust, and the workflows needed to build and deploy from main.

## Changes
- apply infra/identity/terraform: Entra app registration, service principal, and OIDC federated credential
- re-apply infra/environments/terraform to register the service principal as a Test application user
- store deployment settings in GitHub repository secrets
- install build.yml and deploy.yml under .github/workflows
## Testing
- repository secrets are configured and GitHub Actions is enabled for CI/CD runs
'@
Write-Host "`nNext: .lab-scripts/CP06-implement-data-model.ps1" -ForegroundColor Cyan
