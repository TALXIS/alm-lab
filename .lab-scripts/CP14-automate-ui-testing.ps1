#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP14: Automate testing                                           ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Quality gate: a Reqnroll + Playwright BDD UI test project. We scaffold it and add a manual
# (workflow_dispatch) test workflow you can inspect. The point here is the test project +
# workflow exist in source.
#
# The scenarios sign themselves in: "Given I am logged in as 'a warehouse manager'" resolves
# that role to an account in src/Tests.UI/.env, signs in through the real Entra flow (TOTP
# included, for a tenant that enforces MFA) and caches the session per account under
# src/Tests.UI/.auth/. Copy .env.example to .env and fill it in; nothing else is needed, and
# no session has to be captured by hand before a run. See scaffold/11-tests-ui.ps1 and
# src/Tests.UI/Authentication/.
#
# BDD discipline in one paragraph: scenarios speak business language - Given sets context,
# When is one action, Then is an observable outcome, 3-5 steps total - so domain experts
# can read and challenge them. Selectors and waits belong in step definitions, never in the
# feature file. Two rules keep UI tests stable: prefer data-*/test-id selectors over
# display text (which breaks with localization), and never hard-sleep - wait for a
# specific element instead.
#
# UI tests are the top of the pyramid, not the whole pyramid: CP15 adds the fast layers
# underneath (FakeXrmEasy plugin tests and Jest script tests). See
# TALXIS/docs-patterns-practices (bdd-agent-v2) for AI agents that plan, bind and heal
# BDD tests.
#
# Run:  .lab-scripts/CP14-automate-ui-testing.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

$PublisherPrefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP14 — Automated BDD testing"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/11-tests-ui.ps1"
    dotnet build src/Tests.UI/Tests.UI.csproj --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) { Write-Err "dotnet build failed"; exit 1 }
} finally { Pop-Location }

# Test workflow is installed for attendees to inspect, but is manual-only for now
# (workflow_dispatch) — running it against a real environment needs the .env credentials
# above supplied as repository secrets, which is deliberately left as an exercise.
$wf = Join-Path $LabRoot ".github/workflows"
New-Item -ItemType Directory -Path $wf -Force | Out-Null
Copy-Item "$PSScriptRoot/workflows/test.yml" $wf -Force

Save-Checkpoint -Id "cp14" -Message "Add UI BDD test project and PR validation workflow" -Body @'
Add browser-based regression coverage so key warehouse scenarios can be validated. This introduces the Playwright test project, a manual test workflow, and sign-in that the scenarios drive themselves from credentials in a gitignored .env - no session captured by hand before a run.

## Changes
- add src/Tests.UI with Reqnroll and Playwright test assets
- create sample warehouse navigation features (Items, Locations, Transactions) covering every sitemap area and view, plus a cross-area regression scenario, and appsettings.json
- add a Warehouse Picking feature covering the code app's picking flow (blocked over-pick,
  successful pick updates qty on hand) and the barcode scan/lookup flow added in CP11 (manual
  EAN entry - the scan dialog's test hook for a camera-less CI runner), with hand-authored
  custom steps in StepDefinitions/ since the frozen model-driven bindings can't navigate to a
  standalone SPA
- add Authentication/ - persona to account from .env, real Entra sign-in with TOTP for MFA,
  session cached per account under .auth/, both directories gitignored
- add offline unit tests for the two parts that are pure logic: the persona to variable-name
  mapping, and RFC 6238 against the spec's own test vectors
- add .github/workflows/test.yml (manual workflow_dispatch) for the UI suite
## Testing
- dotnet build src/Tests.UI/Tests.UI.csproj passes and the PR workflow is ready to execute
- the offline suite (TestCategory!=live) passes without a browser or an environment
'@
Write-Host "`nNext: .lab-scripts/CP15-implement-unit-tests.ps1" -ForegroundColor Cyan
