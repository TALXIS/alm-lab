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

# Dataverse publisher defaults. CP02 writes them into .lab-state.json; later checkpoints read them back.
$Global:LabDefaultPublisherName   = "TALXISLab"
$Global:LabDefaultPublisherPrefix = "lab"

# The agentbox image bakes a pinned, older txc into /usr/local/bin for fast startup and relies
# on the devcontainer's remoteEnv/postStartCommand to shadow it with a freshly-updated global
# tool on every container start - but that only happens under the actual devcontainer/Codespaces
# lifecycle. Running the image directly (this repo's LOCAL-DRY-RUN.md, CI) never triggers it, so
# every checkpoint has to assert the same PATH precedence itself, in its own process, rather than
# relying on a single earlier checkpoint (or the devcontainer) having already done it.
$env:PATH = "$HOME/.dotnet/tools$([IO.Path]::PathSeparator)$env:PATH"

# Codespaces injects a GITHUB_TOKEN into every terminal, and gh prefers it over your own login.
# Once you've signed in with lab-signin.ps1, use your login instead.
$injectedToken = $env:GITHUB_TOKEN; $env:GITHUB_TOKEN = $null
if ($injectedToken -and -not (gh auth token 2>$null)) { $env:GITHUB_TOKEN = $injectedToken }

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

# ── Template expansion ──────────────────────────────────────────────────────────────────
# Renders a whole-file template from .lab-scripts/templates/ by replacing __TOKEN__
# placeholders with literal values (plain string replace, no regex — so scaffold scripts
# no longer need backtick-escaping for target languages that use $ themselves, like C#
# interpolated strings or JS/TS template literals).
function Expand-LabTemplate {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Destination,
        [hashtable]$Tokens = @{}
    )
    $content = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "../templates/$Path")
    foreach ($key in $Tokens.Keys) {
        $content = $content.Replace("__${key}__", [string]$Tokens[$key])
    }
    $destDir = Split-Path $Destination -Parent
    if ($destDir -and -not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Set-Content -LiteralPath $Destination -Value $content -Encoding UTF8
}

# ── Checkpoint via Pull Request ─────────────────────────────────────────────────────────
# Proper ALM: every checkpoint lands on main through a PR. We branch, commit, push, open a
# PR, pause so you can review the diff + checks in the browser, then merge + tag for rollback.
# Set LAB_AUTO_MERGE=1 to skip the pause (used for unattended testing).
# Set LAB_LOCAL_MODE=1 to skip GitHub entirely — commits merge into main locally, no push/PR.
function Save-Checkpoint {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Message,
        [string]$Body
    )
    Push-Location $LabRoot
    try {
        if (-not (git config user.email)) {
            if ($env:LAB_LOCAL_MODE) {
                git config user.email "agent@local.test"
                git config user.name  "lab-agent"
            } else {
                git config user.email "$(gh api user -q .id)+$(gh api user -q .login)@users.noreply.github.com"
                git config user.name (gh api user -q .login)
            }
        }
        Write-Info "Syncing main..."
        git switch main --quiet 2>&1 | Out-Null
        if (-not $env:LAB_LOCAL_MODE) { git pull --quiet 2>&1 | Out-Null }
        git branch -D $Id 2>&1 | Out-Null
        git switch -c $Id --quiet 2>&1 | Out-Null
        Save-LabState  # write state AFTER branch switch so lab-state.json diff is captured
        git add --all
        if (-not (git status --porcelain)) { Write-Info "No changes for $Id"; git switch main --quiet; return }
        Write-Info "Committing changes..."
        git commit -m "$Id`: $Message" --quiet

        if ($env:LAB_LOCAL_MODE) {
            Write-Info "LAB_LOCAL_MODE: skipping push/PR — merging '$Id' into main locally"
            git switch main --quiet
            git merge --no-ff --quiet -m "Merge $Id`: $Message" $Id 2>&1 | Out-Null
            git branch -D $Id 2>&1 | Out-Null
            git tag -f $Id 2>&1 | Out-Null
            Write-Ok "Committed + tagged $Id locally (rollback: git reset --hard $Id) [LAB_LOCAL_MODE]"
            return
        }

        git push -u origin $Id --force --quiet 2>&1 | Out-Null
        Start-Sleep 3  # let GitHub settle the ref before opening PR
        # Always target the fork's origin repo explicitly (avoids gh resolving upstream instead)
        $forkRepo = (git remote get-url origin) -replace 'https://github.com/',''-replace '\.git$',''
        $prBody = if ([string]::IsNullOrWhiteSpace($Body)) { "## Summary`n$Message" } else { $Body }
        # gh api (REST) rather than gh pr, which uses GitHub's GraphQL API - blocked in some sandboxes.
        $pr = gh api "repos/$forkRepo/pulls" -f base=main -f head=$Id -f title="$Id`: $Message" -f body=$prBody | ConvertFrom-Json
        if (-not $pr.number) { Write-Err "PR failed"; exit 1 }
        Write-Ok "PR opened: $($pr.html_url)"
        if ([Console]::IsInputRedirected -and -not $env:LAB_AUTO_MERGE) {
            # No terminal (e.g. an agent runs this): a person reviews and merges on GitHub.
            Write-Info "Review and merge the PR on GitHub: $($pr.html_url)"
            while ((gh api "repos/$forkRepo/pulls/$($pr.number)" -q .state) -eq 'open') { Start-Sleep 15 }
            if ((gh api "repos/$forkRepo/pulls/$($pr.number)" -q .merged) -ne 'true') { Write-Err "PR was closed without merging"; exit 1 }
        } else {
            if (-not $env:LAB_AUTO_MERGE) { Read-Host "`n  Open the PR link above in your browser, review the diff, then press Enter to merge" }
            # Once CP13 requires the 'build' check, GitHub refuses the merge until it passes.
            Write-Info "Merging (waits for required checks)..."
            while ($true) { gh api -X PUT "repos/$forkRepo/pulls/$($pr.number)/merge" -f merge_method=squash --silent 2>$null; if ($LASTEXITCODE -eq 0) { break }; Start-Sleep 15 }
        }
        git switch main --quiet; git pull --quiet
        git tag -f $Id 2>&1 | Out-Null; git push -f origin $Id --quiet 2>&1 | Out-Null
        Write-Ok "Merged + tagged $Id (rollback: git reset --hard $Id)"
    } finally { Pop-Location }
}

Import-LabState | Out-Null
