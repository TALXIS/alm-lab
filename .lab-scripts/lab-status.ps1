#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                              Lab status / resume check                                 ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Read-only preflight for resuming the lab on a fresh machine, after a restart, or when
# jumping/skipping between checkpoints. It never creates or changes anything — it just
# tells you what .lab-state.json and your git history say has been done, and whether this
# machine's own CLI sessions (gh/txc/az) actually back up what lab-state claims.
#
# Why this matters: .lab-state.json is committed and travels with the repo, but auth
# sessions and CLI profiles live outside the repo, on whatever machine you're on right now.
# A .lab-state.json inherited from another Codespace/VM can say "signed in" or "profile
# ready" while this machine has neither — several checkpoints only find that out deep
# inside a failing command. This script surfaces the mismatch up front instead.
#
# Run:  .lab-scripts/lab-status.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "Lab status"

# ── 1. Checkpoint tags vs lab-state keys ────────────────────────────────────────────────
# Each entry: the checkpoint id, the git tag Save-Checkpoint leaves behind, and the
# lab-state keys that checkpoint is expected to have populated (if any — several
# checkpoints only scaffold files under src/ and don't add new lab-state).
$checkpoints = @(
    @{ Id = "cp01"; Keys = @("txcAuth", "tenantId", "randomIdentifier") }
    @{ Id = "cp02"; Keys = @("slnxName", "publisherName", "publisherPrefix") }
    @{ Id = "cp03"; Keys = @("repo", "mainRulesetId", "mainRulesetName") }
    @{ Id = "cp04"; Keys = @("devEnvUrl", "testEnvUrl", "devProfile", "testProfile") }
    @{ Id = "cp05"; Keys = @("appId") }
    @{ Id = "cp06"; Keys = @() }
    @{ Id = "cp07"; Keys = @() }
    @{ Id = "cp08"; Keys = @() }
    @{ Id = "cp09"; Keys = @() }
    @{ Id = "cp10"; Keys = @() }
    @{ Id = "cp11"; Keys = @("configDataDirectory", "configDataSchemaPath", "configDataFilePath") }
    @{ Id = "cp12"; Keys = @("mainRulesetId") }
    @{ Id = "cp13"; Keys = @() }
    @{ Id = "cp14"; Keys = @() }
)

$tags = @(git -C $LabRoot tag --list "cp*" 2>$null)
$firstMissing = $null

Write-Host "`n── Checkpoints ──" -ForegroundColor Cyan
foreach ($cp in $checkpoints) {
    $tagged = $cp.Id -in $tags
    $missingKeys = @($cp.Keys | Where-Object { -not (Get-LabValue $_) })

    if ($tagged -and $missingKeys.Count -eq 0) {
        Write-Ok "$($cp.Id) — done"
    } elseif ($tagged -and $missingKeys.Count -gt 0) {
        Write-Warn2 "$($cp.Id) — tagged, but lab-state is missing: $($missingKeys -join ', ')"
    } else {
        Write-Info "$($cp.Id) — not run"
        if (-not $firstMissing) { $firstMissing = $cp.Id }
    }
}

# ── 2. Live CLI auth vs what lab-state claims ───────────────────────────────────────────
# Presence in .lab-state.json only means "true on SOME machine at SOME point" — re-check
# against this machine's own CLI sessions before trusting it.
Write-Host "`n── Live auth (this machine) ──" -ForegroundColor Cyan

# Every external call below is wrapped in try/catch: this script's whole purpose is to give
# a clear diagnosis when the environment is broken, so a missing binary (a terminating
# CommandNotFoundException, regardless of $ErrorActionPreference) or unexpected/non-JSON
# output must degrade to a reported status line, not crash the diagnostic tool itself.

$ghUser = $null
try { $ghUser = (gh api user -q .login 2>$null) } catch { $ghUser = $null }
if ($ghUser) { Write-Ok "gh: signed in as $ghUser" } else { Write-Warn2 "gh: not signed in (or gh unavailable) — run CP01" }

$txcAuth = Get-LabValue 'txcAuth'
if ($txcAuth) {
    $liveTxcAuth = $null
    try { $liveTxcAuth = (txc config auth list --format json 2>$null | ConvertFrom-Json -ErrorAction Stop | Where-Object { $_.id -eq $txcAuth } | Select-Object -First 1) } catch { $liveTxcAuth = $null }
    if ($liveTxcAuth) { Write-Ok "txc: auth '$txcAuth' present" } else { Write-Warn2 "txc: lab-state auth '$txcAuth' NOT found locally (or txc unavailable) — run CP01 again" }
} else {
    Write-Info "txc: no auth recorded in lab-state yet"
}

$tenantId = Get-LabValue 'tenantId'
if ($tenantId) {
    $liveTenantId = $null
    try { $liveTenantId = (az account show --query tenantId -o tsv 2>$null) } catch { $liveTenantId = $null }
    if ($liveTenantId -eq $tenantId) { Write-Ok "az: tenant matches ($tenantId)" }
    elseif ($liveTenantId) { Write-Warn2 "az: signed in to a DIFFERENT tenant ($liveTenantId) than lab-state expects ($tenantId)" }
    else { Write-Warn2 "az: not signed in (or az unavailable) — run CP01 again" }
} else {
    Write-Info "az: no tenant recorded in lab-state yet"
}

$liveProfiles = @()
try { $liveProfiles = @(txc config profile list --format json 2>$null | ConvertFrom-Json -ErrorAction Stop).id } catch { $liveProfiles = @() }
foreach ($profileKey in @('devProfile', 'testProfile')) {
    $profileName = Get-LabValue $profileKey
    if (-not $profileName) { continue }
    if ($profileName -in $liveProfiles) { Write-Ok "txc profile '$profileName' ($profileKey) present" }
    else { Write-Warn2 "txc profile '$profileName' ($profileKey) NOT found locally (or txc unavailable) — run CP04 again" }
}

# ── 3. What's next ───────────────────────────────────────────────────────────────────────
Write-Host "`n── Next ──" -ForegroundColor Cyan
if ($firstMissing) {
    Write-Info "Next runnable checkpoint: .lab-scripts/$firstMissing-*.ps1"
} else {
    Write-Ok "All checkpoints done."
}
