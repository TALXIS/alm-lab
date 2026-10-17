#!/usr/bin/env pwsh
#
# Sign in to GitHub, Power Platform, Azure and Power Apps. Safe to re-run: it skips what already works.
#
# Run:  .lab-scripts/lab-signin.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

if ($env:LAB_LOCAL_MODE) { Write-Info "LAB_LOCAL_MODE: skipped sign-in"; return }
if ([Console]::IsInputRedirected) { Write-Err "Signing in is up to you: run .lab-scripts/lab-signin.ps1 in your terminal."; exit 1 }

# ── 1. GitHub ─────────────────────────────────────────────────────────────────────────────
# Your own login - the GITHUB_TOKEN Codespaces provides can't manage rulesets or workflows.
# A GH_TOKEN your environment provides (e.g. a cloud agent sandbox) is used as is.
Write-Step "Sign in 1/4 — GitHub"
Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
if (-not $env:GH_TOKEN) {
    gh auth setup-git --hostname github.com --force   # git pushes with your gh login
    if (-not (gh auth status 2>&1 | Select-String 'workflow')) {
        # Piping input in makes gh print the link and code instead of waiting for Enter.
        '' | gh auth login -h github.com -p https -s workflow --web
    }
}
Write-Ok "GitHub: $(gh api user -q .login)"

# ── 2. Power Platform (txc) ───────────────────────────────────────────────────────────────
# One credential named "lab"; CP04 binds your Dev and Test environments to it.
Write-Step "Sign in 2/4 — Power Platform"
$health = (txc config auth get lab --check-token --format json 2>$null | ConvertFrom-Json).tokenHealth.status
if (-not $health -or $health -eq 'failed') { txc config auth login --alias lab }
$tenantId = (txc config auth get lab --format json | ConvertFrom-Json).tenantId
Write-Ok "Power Platform: tenant $tenantId"

# ── 3. Azure (az) ─────────────────────────────────────────────────────────────────────────
# Same account and tenant as Power Platform: CP05 uses it to call your Test environment.
# Piping the output away also skips az's subscription picker - the lab only needs the tenant.
Write-Step "Sign in 3/4 — Azure"
if ((az account get-access-token --query tenant -o tsv 2>$null) -ne $tenantId) {
    az login --tenant $tenantId --allow-no-subscriptions | Out-Null
}
$account = az account show --query user.name -o tsv
Set-LabValue 'tenantId' $tenantId
Write-Ok "Azure: $account (tenant $tenantId)"

# ── 4. Power Apps (pa) ────────────────────────────────────────────────────────────────────
# Used by the code app (CP11). Same account as Power Platform.
Write-Step "Sign in 4/4 — Power Apps"
# Unlike txc and az, pa can't tell when no browser can open here (Codespaces, containers).
$deviceCode = if ($IsLinux -and -not $env:DISPLAY) { '--device-code' }
if (-not (pa auth status --json | ConvertFrom-Json).signedIn) {
    pa auth login $deviceCode --account $account
}
Write-Ok "Power Apps: signed in"
