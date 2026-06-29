#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║            CP11: Extend branch policies with build checks                              ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# A PR should only merge if it builds. We extend the main ruleset to require the 'build'
# status check (dotnet build, which runs TALXIS workspace validation). Now broken solutions
# can't reach main.
#
# Run:  .lab-scripts/CP11-extend-branch-policies-build-checks.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$repo = Get-LabValue 'repo'; if (-not $repo) { $repo = gh repo view --json nameWithOwner -q .nameWithOwner }

Write-Step "CP11 — Require build check on PRs"

$id = gh api "repos/$repo/rulesets" -q '.[] | select(.name=="alm-lab-main-protection") | .id'
$rules = @(
    @{ type="deletion" }, @{ type="non_fast_forward" },
    @{ type="pull_request"; parameters=@{ required_approving_review_count=0
        dismiss_stale_reviews_on_push=$true; require_code_owner_review=$false
        require_last_push_approval=$false; required_review_thread_resolution=$false } },
    @{ type="required_status_checks"; parameters=@{ strict_required_status_checks_policy=$true
        required_status_checks=@(@{ context="build" }) } }
) | ConvertTo-Json -Depth 10
$tmp = New-TemporaryFile; "{`"rules`":$rules}" | Set-Content $tmp -Encoding UTF8
gh api -X PUT "repos/$repo/rulesets/$id" --input $tmp 2>&1 | Out-Null
Remove-Item $tmp
Write-Ok "Ruleset now requires 'build' to pass"

Save-Checkpoint -Id "cp11" -Message "Require build status checks before merging into main" -Body @'
Tighten the main branch rules so pull requests must pass the build before they can merge. This turns the warehouse solution build into an enforceable quality gate for every change.

## Changes
- update the main branch ruleset in GitHub
- require the build status check on pull requests targeting main
- keep the existing PR-only protection while adding automated validation
## Testing
- ruleset update succeeds and the build check is registered as a required status
'@
Write-Host "`nNext: .lab-scripts/CP12-automate-testing.ps1" -ForegroundColor Cyan
