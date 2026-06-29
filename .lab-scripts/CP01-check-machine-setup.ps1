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
# Run:  .lab-scripts/CP01-check-machine-setup.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP01 — Machine setup"

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
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Write-Ok "$name available"
    } else {
        Write-Err "$name NOT found"
        $missing += $name
    }
}

if ($missing.Count -gt 0) {
    Write-Err "Missing tools: $($missing -join ', '). Open this repo in GitHub Codespaces."
    exit 1
}

# Seed the unique identifier used for all named cloud assets.
$rid = Initialize-RandomIdentifier
Write-Ok "Random identifier for this lab: $rid"

# Ensure TALXIS CLI >= 1.19 (env management). Update the dotnet global tool and prefer it.
$txcVer = (txc --version 2>$null) -replace '\+.*',''
if ([version]($txcVer ? $txcVer : '0.0.0') -lt [version]'1.19.0') {
    Write-Info "Updating TALXIS CLI to latest..."
    dotnet tool update --global TALXIS.CLI 2>&1 | Out-Null
    $env:PATH = "$HOME/.dotnet/tools:$env:PATH"
    Write-Ok "TALXIS CLI: $(txc --version)"
}

# Confirm GitHub auth (needed for branch policies, PRs, secrets later).
gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warn2 "Not logged in to GitHub CLI. Run: gh auth login"
} else {
    Write-Ok "GitHub CLI authenticated"
}

Save-Checkpoint -Id "cp01" -Message "verified machine setup, seeded identifier $rid"
Write-Host "`nNext: .lab-scripts/CP02-create-repository-layout.ps1" -ForegroundColor Cyan
