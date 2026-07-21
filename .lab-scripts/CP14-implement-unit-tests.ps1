#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP14: Implement unit tests                                       ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# The fast layers of the test pyramid. CP13 gave us browser UI tests - thorough but slow
# and environment-bound. This checkpoint adds the two layers underneath, both running in
# milliseconds with no Dataverse environment at all:
#   - Plugins.Tests   - FakeXrmEasy fakes the whole Dataverse pipeline in memory, so the
#                       plugin logic (stock validation, inbound/outbound math) is tested
#                       as plain C#.
#   - Scripts.Tests   - Jest loads the built web-resource bundle with a mocked Xrm object,
#                       so form scripts and ribbon actions are tested as plain JavaScript.
#
# The tests are adapted to OUR app: the plugins require a transaction type and treat
# Inbound (add stock) and Outbound (validate + subtract) differently - tests document that.
#
# One honest constraint: the Dataverse plugin SDK targets .NET Framework (net462), which
# only executes on Windows. In Codespaces (Linux) we compile the plugin tests and run them
# in CI on a windows runner - the new unit-tests workflow does exactly that on every PR.
#
# Run:  .lab-scripts/CP14-implement-unit-tests.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$PublisherName   = Get-LabValue 'publisherName'   'ALMLab'
$PublisherPrefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP14 — Unit tests (plugins + scripts)"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/14-tests-unit.ps1"

    # ── Run script tests — dotnet test drives Jest via the csproj's RunJest target ──
    $bundle = "src/Scripts.UI/build/$($PublisherPrefix)_main.js"
    if (-not (Test-Path $bundle)) {
        Write-Info "Building Scripts.UI (the bundle is the web resource under test)..."
        dotnet build src/Scripts.UI/Scripts.UI.csproj --nologo --verbosity quiet
        if ($LASTEXITCODE -ne 0) { Write-Err "Scripts.UI build failed"; exit 1 }
    }
    Write-Info "Running script unit tests (dotnet test → Jest)..."
    dotnet test src/Scripts.Tests/Scripts.Tests.csproj --nologo
    if ($LASTEXITCODE -ne 0) { Write-Err "Script tests failed"; exit 1 }
    Write-Ok "Script unit tests passed"

    # ── Run plugin tests (FakeXrmEasy) — net462 executes on Windows only ──
    dotnet test src/Plugins.Tests/Plugins.Tests.csproj --nologo
        if ($LASTEXITCODE -ne 0) { Write-Err "Plugin tests failed"; exit 1 }

      Write-Ok "Plugin unit tests passed"


    # ── Install the unit-tests workflow so both suites run on every PR ──
    $wf = Join-Path $LabRoot ".github/workflows"
    New-Item -ItemType Directory -Path $wf -Force | Out-Null
    $unitTestsYml = @'
name: unit-tests
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  unit-tests:
    # windows runner: the Dataverse SDK (and FakeXrmEasy) target net462
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.x'
      - name: Plugin unit tests (FakeXrmEasy)
        run: dotnet test src/Plugins.Tests/Plugins.Tests.csproj --configuration Release
      - name: Build script bundle
        run: dotnet build src/Scripts.UI/Scripts.UI.csproj --configuration Release
      - name: Script unit tests (Jest via dotnet test)
        run: dotnet test src/Scripts.Tests/Scripts.Tests.csproj --configuration Release
'@
    $unitTestsYml | Set-Content -Path (Join-Path $wf "unit-tests.yml") -Encoding UTF8
    Write-Ok "Installed unit-tests.yml (runs on every PR; CP12 shows how to make it required)"
} finally { Pop-Location }

Save-Checkpoint -Id "cp14" -Message "Add plugin and script unit test projects with CI workflow" -Body @'
Add the fast layers of the test pyramid so warehouse logic is verified without a Dataverse environment. Plugin logic is covered with FakeXrmEasy and the form/ribbon scripts with Jest against the built web-resource bundle.

## Changes
- add src/Plugins.Tests with FakeXrmEasy tests for both warehouse plugins
- add src/Scripts.Tests with Jest tests for form and ribbon scripts
- add .github/workflows/unit-tests.yml running both suites on every PR
## Testing
- Jest suite passes locally; plugin suite passes on Windows / the CI windows runner
'@
Write-Host "`n✓ Lab complete — you built, tested and shipped a Power Platform app from source!" -ForegroundColor Green
