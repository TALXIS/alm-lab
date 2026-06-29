#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                          Lab.Common.ps1 — shared helpers                               ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Dot-source this file at the top of every checkpoint:  . "$PSScriptRoot/lib/Lab.Common.ps1"
#
# It provides:
#   - Lab state persistence (.lab-state.json, committed to the repo) so your variables
#     survive terminal/Codespaces crashes and you can resume from any checkpoint.
#   - A random identifier so attendees don't clash on names in the shared training tenant.
#   - Logging helpers and a Save-Checkpoint function that commits, pushes and tags.
#
# ──────────────────────────────────────────────────────────────────────────────────────────

# Repo root = parent of .lab-scripts
$Global:LabRoot      = (Resolve-Path "$PSScriptRoot/../..").Path
$Global:LabStateFile = Join-Path $LabRoot ".lab-state.json"

# ── Logging ────────────────────────────────────────────────────────────────────────────────
function Write-Step  { param([string]$m) Write-Host "`n── $m ──" -ForegroundColor Cyan }
function Write-Ok    { param([string]$m) Write-Host "  ✓ $m" -ForegroundColor Green }
function Write-Warn2 { param([string]$m) Write-Host "  ⚠ $m" -ForegroundColor Yellow }
function Write-Err   { param([string]$m) Write-Host "  ✗ $m" -ForegroundColor Red }
function Write-Info  { param([string]$m) Write-Host "  $m" -ForegroundColor Gray }

# ── State load/save ──────────────────────────────────────────────────────────────────────
# State is a flat hashtable stored as JSON in the repo. Loaded into $Global:Lab.
function Import-LabState {
    if (Test-Path $LabStateFile) {
        $raw = Get-Content -Raw -Path $LabStateFile
        try { $Global:Lab = $raw | ConvertFrom-Json -AsHashtable } catch { $Global:Lab = @{} }
    } else {
        $Global:Lab = @{}
    }
    return $Global:Lab
}

function Save-LabState {
    $Global:Lab | ConvertTo-Json -Depth 10 | Set-Content -Path $LabStateFile -Encoding UTF8
}

function Set-LabValue {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)]$Value)
    if (-not $Global:Lab) { Import-LabState }
    $Global:Lab[$Name] = $Value
    Save-LabState
}

function Get-LabValue {
    param([Parameter(Mandatory)][string]$Name, $Default = $null)
    if (-not $Global:Lab) { Import-LabState }
    if ($Global:Lab.ContainsKey($Name)) { return $Global:Lab[$Name] }
    return $Default
}

# Seed the random identifier once; reused for all unique names in the shared tenant.
function Initialize-RandomIdentifier {
    if (-not (Get-LabValue 'randomIdentifier')) {
        Set-LabValue 'randomIdentifier' (Get-Random -Minimum 1000 -Maximum 9999)
    }
    return (Get-LabValue 'randomIdentifier')
}

# ── Checkpoint via Pull Request ─────────────────────────────────────────────────────────
# Proper ALM: every checkpoint lands on main through a PR. We branch, commit, push, open a
# PR, pause so you can review the diff + checks in the browser, then merge + tag for rollback.
# Set LAB_AUTO_MERGE=1 to skip the pause (used for unattended testing).
function Save-Checkpoint {
    param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Message)
    Save-LabState
    Push-Location $LabRoot
    try {
        git add --all
        $branch = "$Id"
        git switch -c $branch --quiet 2>&1 | Out-Null
        if (git status --porcelain) { git commit -m "$Id`: $Message" --quiet }
        git push -u origin $branch --quiet 2>&1 | Out-Null
        gh pr create --base main --head $branch --title "$Id`: $Message" --body "Checkpoint $Id" 2>&1 | Out-Null
        $url = gh pr view $branch --json url -q .url
        Write-Ok "PR opened: $url"
        if (-not $env:LAB_AUTO_MERGE) { Read-Host "  Review the PR in your browser, then press Enter to merge" }
        gh pr checks $branch --watch 2>&1 | Out-Null
        gh pr merge $branch --squash --delete-branch --admin 2>&1 | Out-Null
        git switch main --quiet; git pull --quiet
        git tag -f $Id 2>&1 | Out-Null
        git push -f origin $Id --quiet 2>&1 | Out-Null
        Write-Ok "Merged + tagged $Id (rollback: git reset --hard $Id)"
    } finally { Pop-Location }
}

Import-LabState | Out-Null
