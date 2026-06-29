#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP12: Automate testing                                           ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Quality gate: a Reqnroll + Playwright BDD UI test project. We scaffold it and add a manual
# (workflow_dispatch) test workflow you can inspect — running it live needs a captured auth
# state, which we cover later. The point here is the test project + workflow exist in source.
#
# Run:  .lab-scripts/CP12-automate-testing.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP12 — Automated BDD testing"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/11-tests-ui.ps1"
    dotnet build src/Tests.UI/Tests.UI.csproj --nologo --verbosity quiet
} finally { Pop-Location }

# Test workflow is installed for attendees to inspect, but is manual-only for now
# (workflow_dispatch) — live UI tests need a captured auth state, covered later in the lab.
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

Save-Checkpoint -Id "cp12" -Message "Add UI BDD test project and PR validation workflow" -Body @'
Add browser-based regression coverage so key warehouse scenarios can be validated. This introduces the Playwright test project and a manual test workflow; running it live needs a captured auth state, covered later in the lab.

## Changes
- add src/Tests.UI with Reqnroll and Playwright test assets
- create a sample warehouse navigation feature and appsettings.json
- add .github/workflows/test.yml (manual workflow_dispatch) for the UI suite
## Testing
- dotnet build src/Tests.UI/Tests.UI.csproj passes and the PR workflow is ready to execute
'@
Write-Host "`n✓ Lab complete — you built and shipped a Power Platform app from source!" -ForegroundColor Green
