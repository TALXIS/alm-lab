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

    # ── Run script tests (Jest) — cross-platform, immediate feedback ──
    $bundle = "src/Scripts.UI/build/$($PublisherPrefix)_main.js"
    if (-not (Test-Path $bundle)) {
        Write-Info "Building the Scripts.UI bundle (needed as the web resource under test)..."
        Push-Location src/Scripts.UI
        npm install --no-fund --no-audit | Out-Null
        npm run build | Out-Null
        Pop-Location
    }
    if (-not (Test-Path "src/Scripts.Tests/node_modules")) {
        Push-Location src/Scripts.Tests
        npm install --no-fund --no-audit | Out-Null
        Pop-Location
    }
    Write-Info "Running script unit tests (Jest)..."
    Push-Location src/Scripts.Tests
    $env:JETS_CORE   = Join-Path $LabRoot "src/Scripts.Tests/jest-core"
    $env:WEBRES_PATH = Join-Path $LabRoot $bundle
    npx jest --runInBand --ci --env=jsdom
    $jestExit = $LASTEXITCODE
    Pop-Location
    if ($jestExit -ne 0) { Write-Err "Jest tests failed"; exit 1 }
    Write-Ok "Script unit tests passed"

    # ── Run plugin tests (FakeXrmEasy) — net462 executes on Windows only ──
    if ($IsWindows) {
        dotnet test src/Plugins.Tests/Plugins.Tests.csproj --nologo
        if ($LASTEXITCODE -ne 0) { Write-Err "Plugin tests failed"; exit 1 }
        Write-Ok "Plugin unit tests passed"
    } else {
        dotnet build src/Plugins.Tests/Plugins.Tests.csproj --nologo --verbosity quiet
        if ($LASTEXITCODE -ne 0) { Write-Err "Plugin test build failed"; exit 1 }
        Write-Ok "Plugin tests compiled (net462 executes on the CI windows runner)"
    }

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
        working-directory: src/Scripts.UI
        run: |
          npm install --no-fund --no-audit
          npm run build
      - name: Script unit tests (Jest)
        working-directory: src/Scripts.Tests
        run: |
          npm install --no-fund --no-audit
          $env:JETS_CORE = "$env:GITHUB_WORKSPACE\src\Scripts.Tests\jest-core"
          $env:WEBRES_PATH = "$env:GITHUB_WORKSPACE\src\Scripts.UI\build\__PREFIX___main.js"
          npx jest --runInBand --ci --env=jsdom
'@
    $unitTestsYml.Replace('__PREFIX__', $PublisherPrefix) |
        Set-Content -Path (Join-Path $wf "unit-tests.yml") -Encoding UTF8
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
Write-Host "`nNext: .lab-scripts/CP16-implement-code-app.ps1" -ForegroundColor Cyan
