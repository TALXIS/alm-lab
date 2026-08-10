#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP10: Deploy & Sync with Dev environment                         ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# After implementing the app in source (CP06–09), we deploy the full package to Dev so we
# can work with a live running app. This is the "source → environment" push.
#
# Then we'll make manual changes in the Dev environment (e.g. tweaking a security role)
# and pull them back to source with `txc env solution pull`. This demonstrates the
# bidirectional inner loop: source ↔ environment.
#
# In auto mode: deploy + pull (no manual changes expected).
#
# Run:  .lab-scripts/CP10-deploy-and-sync.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP10 — Deploy to Dev & sync changes back"

$devUrl = Get-LabValue 'devEnvUrl'
if (-not $devUrl) { Write-Err "Dev environment URL not found in lab state. Run CP04 first."; exit 1 }

# ──────────────────────────────────────────────────────────────────────────────────────────
# Step 1: Build the full Package Deployer package and deploy to Dev.
# This mirrors what the CD pipeline does for Test, but locally for the Dev environment.
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Info "Building the deployment package..."
$pkgProj    = Join-Path $LabRoot "src/Packages.Main/Packages.Main.csproj"
$publishDir = Join-Path $LabRoot ".lab-scripts/.tmp-deploy"
Remove-Item $publishDir -Recurse -Force -ErrorAction SilentlyContinue

dotnet publish $pkgProj -c Release -o $publishDir --nologo --verbosity quiet
if ($LASTEXITCODE -ne 0) { Write-Err "dotnet publish failed"; exit 1 }

# Locate the pdpkg.zip (Package Deployer package archive).
$pdpkg = Get-ChildItem (Join-Path $LabRoot "src/Packages.Main/bin/Release") -Filter "*.pdpkg.zip" -Recurse | Select-Object -First 1
if (-not $pdpkg) { Write-Err "Packages.Main.pdpkg.zip not found after publish"; exit 1 }
Copy-Item $pdpkg.FullName (Join-Path $publishDir "Packages.Main.pdpkg.zip") -Force
Write-Ok "Package built: $($pdpkg.Name)"

Write-Info "Deploying package to Dev environment ($devUrl)..."
txc env pkg import (Join-Path $publishDir "Packages.Main.pdpkg.zip") --profile dev
if ($LASTEXITCODE -ne 0) { Write-Err "Package import to Dev failed"; exit 1 }
Write-Ok "Package deployed to Dev environment"

# Cleanup temp publish dir.
Remove-Item $publishDir -Recurse -Force -ErrorAction SilentlyContinue

# ──────────────────────────────────────────────────────────────────────────────────────────
# Step 2: Pause for manual environment changes (interactive mode).
# In a real workflow you'd open the environment, tweak security roles, forms, etc.
# We'll then pull those changes back to source.
# ──────────────────────────────────────────────────────────────────────────────────────────

$autoMode = $env:LAB_AUTO -eq '1'
if (-not $autoMode) {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║  Your app is now live in the Dev environment!                        ║" -ForegroundColor Yellow
    Write-Host "║                                                                      ║" -ForegroundColor Yellow
    Write-Host "║  Open $devUrl" -ForegroundColor Yellow
    Write-Host "║  Try: Settings → Security Roles → modify the Warehouse Operator role ║" -ForegroundColor Yellow
    Write-Host "║                                                                      ║" -ForegroundColor Yellow
    Write-Host "║  Press ENTER when you're done making changes...                      ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press ENTER to continue"
}

# ──────────────────────────────────────────────────────────────────────────────────────────
# Step 3: Pull environment changes back to source.
# txc env solution pull downloads the unmanaged solution(s) from Dev into the source tree.
# This is how manual customizations in the maker portal get committed as source.
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Info "Pulling solution changes from Dev back to source..."
$solutions = @("Solutions.Security")  # The one we asked them to modify
foreach ($sol in $solutions) {
    $solPath = Join-Path $LabRoot "src/$sol"
    if (Test-Path $solPath) {
        txc env solution pull --folder $solPath --profile dev
        if ($LASTEXITCODE -ne 0) { Write-Warn2 "Pull for $sol returned non-zero (may be OK if no changes)" }
    }
}
Write-Ok "Solution pull complete"

# Show what changed (if anything).
$changes = git -C $LabRoot status --short -- src/
if ($changes) {
    Write-Info "Changes pulled from environment:"
    Write-Host $changes
} else {
    Write-Info "No environment changes detected (expected in auto mode)."
}

Save-Checkpoint -Id "cp10" -Message "Deploy package to Dev and sync environment changes" -Body @'
Deploy the full solution package to the Dev environment and demonstrate the bidirectional inner loop: push source to environment, make manual changes, then pull them back with txc env solution pull.

## Changes
- deploy the built package (all 4 solutions) to the Dev Dataverse environment
- pull any manual security role changes back to src/Solutions.Security
## Testing
- warehouse app is accessible in the Dev environment
- txc env solution pull completes without error
'@
Write-Host "`nNext: .lab-scripts/CP11-move-configuration.ps1" -ForegroundColor Cyan
