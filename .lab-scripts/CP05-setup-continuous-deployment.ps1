#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                    CP05: Setup Continuous Deployment                                   ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# GitHub Actions will build the Package Deployer package and deploy it to Test on every push
# to main. We authenticate with workload identity federation (OIDC) — no secrets/certs:
#   1. Create an Entra app registration + service principal (your own).
#   2. Add a federated credential trusting this repo's main branch.
#   3. Add the SP as an application user in the Test environment.
#   4. Store AZURE_CLIENT_ID / AZURE_TENANT_ID / DATAVERSE_TEST_URL as GitHub secrets.
#   5. Install build.yml + deploy.yml workflows (package deploy via powerplatform-actions).
#
# Run:  .lab-scripts/CP05-setup-continuous-deployment.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP05 — Continuous Deployment (OIDC)"

$rid     = Initialize-RandomIdentifier
$repo    = Get-LabValue 'repo'
$testUrl = Get-LabValue 'testEnvUrl'
if (-not $repo -and -not $env:LAB_LOCAL_MODE) { $originUrl = git -C $LabRoot remote get-url origin 2>$null; if ($originUrl -match 'github\.com[:/](.+?)(?:\.git)?$') { $repo = $Matches[1] }; Set-LabValue 'repo' $repo }
if (-not $testUrl) { Write-Err "Run CP04 first (Test environment URL missing)"; exit 1 }

if ($env:LAB_LOCAL_MODE) {
    Write-Info "LAB_LOCAL_MODE: skipped — would verify Azure sign-in, create an Entra app"
    Write-Info "  registration + service principal, add a federated credential trusting"
    Write-Info "  this repo's main branch, and add the SP as a System Administrator"
    Write-Info "  application user in the Test environment via the Dataverse OData API."
    $tenantId = Get-LabValue 'tenantId'; if (-not $tenantId) { $tenantId = "00000000-0000-0000-0000-000000000000"; Set-LabValue 'tenantId' $tenantId }
    $appId = Get-LabValue 'appId'; if (-not $appId) { $appId = "00000000-0000-0000-0000-000000000000"; Set-LabValue 'appId' $appId }
} else {

# Step 1: Verify Azure sign-in and tenant (done in CP01).
$tenantId = Get-LabValue 'tenantId'
if (-not $tenantId) {
    $tenantId = az account show --query tenantId -o tsv 2>$null
    if (-not $tenantId) { Write-Err "Not signed in to Azure — run CP01 first"; exit 1 }
    Set-LabValue 'tenantId' $tenantId
}
Write-Ok "Azure: tenant $tenantId"

# Step 2: App registration + service principal.
$appName = "wm-deploy-$rid"
Set-LabValue 'appName' $appName
$appId = Get-LabValue 'appId'
if (-not $appId) {
    $appId = az ad app list --display-name $appName --query "[0].appId" -o tsv 2>$null
    if (-not $appId) {
        $appId = az ad app create --display-name $appName --query appId -o tsv
        az ad sp create --id $appId | Out-Null
        Write-Ok "App registration: $appName ($appId)"
    } else {
        Write-Ok "App registration already exists: $appName ($appId)"
    }
}
Set-LabValue 'appId' $appId
$appObjectId = az ad app show --id $appId --query id -o tsv 2>$null
if ($appObjectId) { Set-LabValue 'appObjectId' $appObjectId }
$servicePrincipalObjectId = az ad sp show --id $appId --query id -o tsv 2>$null
if (-not $servicePrincipalObjectId) {
    az ad sp create --id $appId | Out-Null
    $servicePrincipalObjectId = az ad sp show --id $appId --query id -o tsv 2>$null
}
if ($servicePrincipalObjectId) { Set-LabValue 'servicePrincipalObjectId' $servicePrincipalObjectId }

# Step 3: Federated credential trusting main of this repo.
$fedCredentialName = "github-main"
Set-LabValue 'federatedCredentialName' $fedCredentialName
$fed = @{ name=$fedCredentialName; issuer="https://token.actions.githubusercontent.com";
          subject="repo:$repo`:ref:refs/heads/main"; audiences=@("api://AzureADTokenExchange") } | ConvertTo-Json
$tmp = New-TemporaryFile; Set-Content $tmp $fed -Encoding UTF8
if (-not (az ad app federated-credential list --id $appId --query "[?name=='$fedCredentialName'] | [0].name" -o tsv 2>$null)) {
    az ad app federated-credential create --id $appId --parameters "@$tmp" 2>&1 | Out-Null
}
Remove-Item $tmp; Write-Ok "Federated credential (repo:${repo}:ref:refs/heads/main)"

# Step 4: Add SP as application user with System Administrator role in Test env.
# We use the Dataverse OData API directly (pac admin assign-user requires a pac
# auth profile which is not available in Codespaces; az is already authenticated).
# NOTE: System Administrator keeps the lab simple but breaks the least-privilege rule we
# apply to users in CP08. In production, give the deploy principal a custom role scoped to
# what imports actually need, and never a tenant-level Power Platform admin role.
$dvToken = (az account get-access-token --resource $testUrl --query accessToken -o tsv 2>$null)
$dvHeaders = @{ Authorization="Bearer $dvToken"; 'Content-Type'='application/json'; 'OData-Version'='4.0' }
$dvBase   = $testUrl.TrimEnd('/')

# Check if already registered
$existing = (Invoke-RestMethod "$dvBase/api/data/v9.2/systemusers?`$filter=applicationid eq $appId&`$select=systemuserid" -Headers $dvHeaders).value
if (-not $existing) {
    # Get root business unit
    $buId = (Invoke-RestMethod "$dvBase/api/data/v9.2/businessunits?`$filter=parentbusinessunitid eq null&`$select=businessunitid" -Headers $dvHeaders).value[0].businessunitid
    # Create application user
    $body = @{ applicationid=$appId; 'businessunitid@odata.bind'="/businessunits($buId)" } | ConvertTo-Json
    Invoke-RestMethod "$dvBase/api/data/v9.2/systemusers" -Method Post -Headers $dvHeaders -Body $body | Out-Null
    $existing = (Invoke-RestMethod "$dvBase/api/data/v9.2/systemusers?`$filter=applicationid eq $appId&`$select=systemuserid" -Headers $dvHeaders).value
}
$userId = $existing[0].systemuserid
# Assign System Administrator role (root BU scope only)
$roleId = (Invoke-RestMethod "$dvBase/api/data/v9.2/roles?`$filter=name eq 'System Administrator' and _parentroleid_value eq null&`$select=roleid" -Headers $dvHeaders).value[0].roleid
$alreadyAssigned = (Invoke-RestMethod "$dvBase/api/data/v9.2/systemusers($userId)/systemuserroles_association?`$filter=roleid eq $roleId&`$select=roleid" -Headers $dvHeaders).value
if (-not $alreadyAssigned) {
    $ref = @{ '@odata.id'="$dvBase/api/data/v9.2/roles($roleId)" } | ConvertTo-Json
    Invoke-RestMethod "$dvBase/api/data/v9.2/systemusers($userId)/systemuserroles_association/`$ref" -Method Post -Headers $dvHeaders -Body $ref | Out-Null
}
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
Set-LabValue 'dataverseTestUrl' $testUrl

# Step 6: Enable GitHub Actions on the fork (forks have them disabled by default).
if ($env:LAB_LOCAL_MODE) {
    Write-Info "LAB_LOCAL_MODE: skipped — would run 'gh api -X PUT repos/<repo>/actions/permissions'"
} else {
    gh api -X PUT "repos/$repo/actions/permissions" -F enabled=true -f allowed_actions=all 2>&1 | Out-Null
    Write-Ok "GitHub Actions enabled on the fork"
}

# Step 7: Install workflows. Pushing files under .github/workflows needs the 'workflow' scope.
if (-not $env:LAB_LOCAL_MODE -and -not ((gh auth status 2>&1) -match 'workflow')) {
    Write-Info "Granting GitHub CLI the 'workflow' scope (needed to push Actions)..."
    gh auth refresh -h github.com -s workflow
}
$wf = Join-Path $LabRoot ".github/workflows"
New-Item -ItemType Directory -Path $wf -Force | Out-Null
Copy-Item "$PSScriptRoot/workflows/build.yml"  $wf -Force
Copy-Item "$PSScriptRoot/workflows/deploy.yml" $wf -Force
Write-Ok "Installed build.yml + deploy.yml"

Save-Checkpoint -Id "cp05" -Message "Configure OIDC deployment identity and GitHub workflows" -Body @'
Set up GitHub Actions deployment for the warehouse app without long-lived secrets. This adds an Entra application identity, federated trust, and the workflows needed to build and deploy from main.

## Changes
- create an Entra app registration, service principal, and OIDC credential
- store deployment settings in GitHub repository secrets
- install build.yml and deploy.yml under .github/workflows
## Testing
- repository secrets are configured and GitHub Actions is enabled for CI/CD runs
'@
Write-Host "`nNext: .lab-scripts/CP06-implement-data-model.ps1" -ForegroundColor Cyan
