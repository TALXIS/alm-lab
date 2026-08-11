#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP13: Automate testing                                           ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Quality gate: a Reqnroll + Playwright BDD UI test project. We scaffold it and add a manual
# (workflow_dispatch) test workflow you can inspect — running it live needs a captured auth
# state (the capture steps are described in scaffold/11-tests-ui.ps1). The point here is
# the test project + workflow exist in source.
#
# BDD discipline in one paragraph: scenarios speak business language - Given sets context,
# When is one action, Then is an observable outcome, 3-5 steps total - so domain experts
# can read and challenge them. Selectors and waits belong in step definitions, never in the
# feature file. Two rules keep UI tests stable: prefer data-*/test-id selectors over
# display text (which breaks with localization), and never hard-sleep - wait for a
# specific element instead.
#
# UI tests are the top of the pyramid, not the whole pyramid: CP14 adds the fast layers
# underneath (FakeXrmEasy plugin tests and Jest script tests). See
# TALXIS/docs-patterns-practices (bdd-agent-v2) for AI agents that plan, bind and heal
# BDD tests.
#
# Run:  .lab-scripts/CP13-automate-ui-testing.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP13 — Automated BDD testing"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/11-tests-ui.ps1"
    dotnet build src/Tests.UI/Tests.UI.csproj --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) { Write-Err "dotnet build failed"; exit 1 }
} finally { Pop-Location }

# Test workflow is installed for attendees to inspect, but is manual-only for now
# (workflow_dispatch) — live UI tests need a captured auth state; the capture steps are
# described in scaffold/11-tests-ui.ps1.
$wf = Join-Path $LabRoot ".github/workflows"
New-Item -ItemType Directory -Path $wf -Force | Out-Null
@'
name: test
on:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.x'
      - run: dotnet test src/Tests.UI/Tests.UI.csproj --configuration Release
        env:
          TXC_HEADLESS: 'true'
'@ | Set-Content -Path (Join-Path $wf "test.yml") -Encoding UTF8

Save-Checkpoint -Id "cp13" -Message "Add UI BDD test project and PR validation workflow" -Body @'
Add browser-based regression coverage so key warehouse scenarios can be validated. This introduces the Playwright test project and a manual test workflow; running it live needs a captured Playwright auth state (see the scaffold script comments for the capture steps).

## Changes
- add src/Tests.UI with Reqnroll and Playwright test assets
- create a sample warehouse navigation feature and appsettings.json
- add .github/workflows/test.yml (manual workflow_dispatch) for the UI suite
## Testing
- dotnet build src/Tests.UI/Tests.UI.csproj passes and the PR workflow is ready to execute
'@
Write-Host "`nNext: .lab-scripts/CP14-implement-unit-tests.ps1" -ForegroundColor Cyan
