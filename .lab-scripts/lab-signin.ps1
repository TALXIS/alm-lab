#!/usr/bin/env pwsh
#
# Sign in to GitHub, Power Platform and Azure. Safe to re-run: it skips what already works.
#
# Run:  .lab-scripts/lab-signin.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

if ($env:LAB_LOCAL_MODE) { Write-Info "LAB_LOCAL_MODE: skipped sign-in"; return }
if ([Console]::IsInputRedirected) { Write-Err "Signing in is up to you: run .lab-scripts/lab-signin.ps1 in your terminal."; exit 1 }

# ── 1. GitHub ─────────────────────────────────────────────────────────────────────────────
# Your own login - the token Codespaces provides can't manage rulesets, secrets or workflows.
Write-Step "Sign in 1/3 — GitHub"
Remove-Item Env:GITHUB_TOKEN, Env:GH_TOKEN -ErrorAction SilentlyContinue
if (-not (gh auth status 2>&1 | Select-String 'workflow')) {
    gh auth login -h github.com -p https -s workflow --web
}
gh auth setup-git
Write-Ok "GitHub: $(gh api user -q .login)"

# ── 2. Power Platform (txc) ───────────────────────────────────────────────────────────────
Write-Step "Sign in 2/3 — Power Platform"
$auth = Get-LabValue 'txcAuth' (txc config auth list --format json | ConvertFrom-Json | Select-Object -First 1).id
if ($auth) { txc config auth get $auth --check-token *> $null }
if (-not $auth -or $LASTEXITCODE -ne 0) {
    $before = (txc config auth list --format json | ConvertFrom-Json).id
    txc config auth login
    $new = (txc config auth list --format json | ConvertFrom-Json).id | Where-Object { $_ -notin $before }
    if ($new) { $auth = $new }
}
$tenantId = (txc config auth get $auth --format json | ConvertFrom-Json).tenantId
Set-LabValue 'txcAuth' $auth
Write-Ok "Power Platform: $auth (tenant $tenantId)"

# ── 3. Azure (az) ─────────────────────────────────────────────────────────────────────────
# Same account and tenant as Power Platform.
Write-Step "Sign in 3/3 — Azure"
if ((az account get-access-token --query tenant -o tsv 2>$null) -ne $tenantId) {
    az login --tenant $tenantId --allow-no-subscriptions --use-device-code | Out-Null
}
Set-LabValue 'tenantId' $tenantId
Write-Ok "Azure: $(az account show --query user.name -o tsv) (tenant $tenantId)"
