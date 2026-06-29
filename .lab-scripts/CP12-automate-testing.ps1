#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP12: Automate testing                                           ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Quality gate: a Reqnroll + Playwright BDD UI test project. We scaffold it and add a test
# workflow that runs on PRs, so behaviour is verified before merge alongside the build.
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

# Test workflow runs on PRs (alongside build).
$wf = Join-Path $LabRoot ".github/workflows"
New-Item -ItemType Directory -Path $wf -Force | Out-Null
@'
name: test
on:
  pull_request:
    branches: [main]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.x'
      - run: dotnet test src/Tests.UI/Tests.UI.csproj --configuration Release
        env:
          TXC_HEADLESS: 'true'
'@ | Set-Content -Path (Join-Path $wf "test.yml") -Encoding UTF8

Save-Checkpoint -Id "cp12" -Message "BDD UI tests + test workflow"
Write-Host "`n✓ Lab complete — you built and shipped a Power Platform app from source!" -ForegroundColor Green
