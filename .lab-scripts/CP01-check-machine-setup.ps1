#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                          CP01: Check machine setup                                     ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Before we develop a Power Platform app with proper ALM, we confirm that every tool the
# lab depends on is available. In Codespaces (agentbox image) they all are — this is your
# sanity check. We also seed a random identifier so your environment/app names won't clash
# with other attendees in the shared training tenant.
#
# We then sign in to all three services at once so you are not interrupted later:
#   1. GitHub CLI          — branch rules, PRs, secrets, Actions
#   2. TALXIS CLI (txc)    — Power Platform environments and deploy
#   3. Azure CLI (az)      — Entra app registrations and OIDC federation
#
# Run:  .lab-scripts/CP01-check-machine-setup.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP01 — Machine setup + sign-in"

# ── 1. Tool check ────────────────────────────────────────────────────────────────────────
$tools = [ordered]@{
    "dotnet" = "dotnet --version"     # .NET SDK — builds solutions, plugins, packages
    "git"    = "git --version"        # version control
    "gh"     = "gh --version"         # GitHub CLI — repo, PRs, secrets, workflows
    "pac"    = "pac help"             # Power Platform CLI
    "txc"    = "txc --version"        # TALXIS CLI — scaffolding, env, deploy
    "az"     = "az version"           # Azure CLI — app registration + OIDC
}

$missing = @()
foreach ($name in $tools.Keys) {
    $cmd = $tools[$name].Split(' ')[0]
    if (Get-Command $cmd -ErrorAction SilentlyContinue) { Write-Ok "$name available" }
    else { Write-Err "$name NOT found"; $missing += $name }
}
if ($missing.Count -gt 0) {
    Write-Err "Missing tools: $($missing -join ', '). Open this repo in GitHub Codespaces."
    exit 1
}

# Seed the unique identifier used for all named cloud assets.
$rid = Initialize-RandomIdentifier
Write-Ok "Random identifier for this lab: $rid"

# Ensure TALXIS CLI is latest (picks up any last-minute fixes).
Write-Info "Updating TALXIS CLI to latest..."
dotnet tool update --global TALXIS.CLI 2>&1 | Out-Null
$env:PATH = "$HOME/.dotnet/tools:$env:PATH"
Write-Ok "TALXIS CLI: $((txc --version) -replace '\+.*','')"

# ── 2. GitHub CLI sign-in (workflow + delete_repo scopes needed for the lab) ────────────
Write-Step "Sign in 1/3 — GitHub"
# Codespaces commonly injects GITHUB_TOKEN, which blocks interactive `gh auth login`.
if ($env:GITHUB_TOKEN) {
    Write-Info "Detected GITHUB_TOKEN in environment; clearing it so GitHub CLI can store login credentials."
    Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
}
$ghScopes = (gh auth status 2>&1 | Select-String 'Token scopes') -replace '.*Token scopes: ',''
$needsRefresh = (-not $ghScopes) -or ($ghScopes -notmatch 'workflow')
if ($needsRefresh) {
    Write-Info "Logging in to GitHub (browser or device code)..."
    gh auth login -h github.com -p https -s workflow,delete_repo --web
    if ($LASTEXITCODE -ne 0) { Write-Err "GitHub login failed"; exit 1 }
}
gh auth setup-git 2>&1 | Out-Null
Write-Ok "GitHub: $(gh api user -q .login)"

# ── 3. TALXIS CLI (txc) — Power Platform / Dataverse ────────────────────────────────────
Write-Step "Sign in 2/3 — Power Platform (txc)"
# txc config auth login shows a device code and waits. Runs in-terminal so TTY is present.
$existingAuth = (txc config auth list --format json 2>$null | ConvertFrom-Json | Select-Object -First 1).id
if (-not $existingAuth) {
    Write-Info "Open https://aka.ms/devicelogin and enter the code shown below:"
    txc config auth login --device-code
    if ($LASTEXITCODE -ne 0) { Write-Err "Power Platform sign-in failed"; exit 1 }
    $existingAuth = (txc config auth list --format json 2>$null | ConvertFrom-Json | Select-Object -First 1).id
}
Set-LabValue 'txcAuth' $existingAuth
Write-Ok "Power Platform: $existingAuth"

# ── 4. Azure CLI — Entra / app registrations ─────────────────────────────────────────────
Write-Step "Sign in 3/3 — Azure (az)"
$tenantId = az account show --query tenantId -o tsv 2>$null
if (-not $tenantId) {
    Write-Info "Open https://aka.ms/devicelogin and enter the code shown below:"
    az login --use-device-code --allow-no-subscriptions | Out-Null
    $tenantId = az account show --query tenantId -o tsv
}
Set-LabValue 'tenantId' $tenantId
Write-Ok "Azure: tenant $tenantId"

Save-Checkpoint -Id "cp01" -Message "Verify developer tooling and initialize lab credentials" -Body @'
Verify the local toolchain and sign in to the services required to build and deploy the warehouse app. This seeds shared lab state so later checkpoints can reuse the same identities and environment metadata.

## Changes
- verify dotnet, git, gh, pac, txc, and az are available
- authenticate GitHub CLI, TALXIS CLI, and Azure CLI
- persist the random identifier, tenant id, and auth profile references
## Testing
- tool checks pass; authenticated sessions are ready for subsequent scripts
'@
Write-Host "`nNext: .lab-scripts/CP02-create-repository-layout.ps1" -ForegroundColor Cyan
