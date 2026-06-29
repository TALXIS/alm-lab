#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                    CP03: Setup Continuous Integration                                  ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# We adopt a trunk-based workflow: everyone integrates into 'main' through short-lived
# branches and pull requests. To protect the trunk we add a branch ruleset that:
#   - blocks direct pushes to main (changes must come via PR)
#   - requires the PR to be up to date and (later, CP11) pass the build check
#
# We work on YOUR fork, so we detect owner/repo from the git origin remote.
#
# Run:  .lab-scripts/CP03-setup-continuous-integration.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP03 — Continuous Integration (branch protection)"

# Step 1: Resolve the fork (owner/repo) from the origin remote (not the upstream parent).
$originUrl = git -C $LabRoot remote get-url origin 2>$null
$repo = if ($originUrl -match 'github\.com[:/](.+?)(?:\.git)?$') { $Matches[1] } else { $null }
if (-not $repo) { Write-Err "Could not resolve origin repo. Run 'gh auth login' and ensure origin is your fork."; exit 1 }
Set-LabValue 'repo' $repo
Write-Ok "Repository: $repo"

# Step 2: Create a ruleset requiring pull requests into main (no direct pushes).
$ruleset = @{
    name        = "alm-lab-main-protection"
    target      = "branch"
    enforcement = "active"
    conditions  = @{ ref_name = @{ include = @("~DEFAULT_BRANCH"); exclude = @() } }
    rules       = @(
        @{ type = "deletion" },
        @{ type = "non_fast_forward" },
        @{ type = "pull_request"; parameters = @{
            required_approving_review_count   = 0
            dismiss_stale_reviews_on_push     = $true
            require_code_owner_review         = $false
            require_last_push_approval        = $false
            required_review_thread_resolution = $false
        }}
    )
} | ConvertTo-Json -Depth 10

$tmp = New-TemporaryFile
Set-Content -Path $tmp -Value $ruleset -Encoding UTF8
gh api -X POST "repos/$repo/rulesets" --input $tmp 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Write-Ok "Ruleset created — main now requires PRs" }
else { Write-Warn2 "Ruleset may already exist (skipping)" }
Remove-Item $tmp -ErrorAction SilentlyContinue

# Step 3: Demonstrate the loop — create a topic branch for upcoming work.
Push-Location $LabRoot
try {
    git checkout main --quiet 2>$null
    git checkout -b "setup/runtime" --quiet 2>$null
    Write-Ok "Created topic branch: setup/runtime"
} finally { Pop-Location }

Save-Checkpoint -Id "cp03" -Message "branch protection + topic branch workflow"
Write-Host "`nNext: .lab-scripts/CP04-setup-runtime.ps1" -ForegroundColor Cyan
