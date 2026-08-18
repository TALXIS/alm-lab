#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP14: Implement unit tests                                       ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# The fast layers of the test pyramid. CP13 gave us browser UI tests - thorough but slow
# and environment-bound. This checkpoint adds the two layers underneath, both running in
# milliseconds with no Dataverse environment at all:
#   - Tests.Plugins   - FakeXrmEasy fakes the whole Dataverse pipeline in memory, so the
#                       plugin logic (stock validation, inbound/outbound math) is tested
#                       as plain C#.
#   - Tests.Scripts   - Jest loads the built web-resource bundle with a mocked Xrm object,
#                       so form scripts and ribbon actions are tested as plain JavaScript.
#
# The tests are adapted to OUR app: the plugins require a transaction type and treat
# Inbound (add stock) and Outbound (validate + subtract) differently - tests document that.
#
# One honest constraint: the plugin assembly itself must stay net462 - the Dataverse
# sandbox still runs .NET Framework. The tests don't share that constraint: the template
# targets modern .NET with FakeXrmEasy 3.x, so the whole suite runs anywhere (Codespaces,
# the ubuntu CI runner). The scaffold only bridges the net10-to-net462 project reference -
# see 14-tests-unit.ps1.
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
    dotnet test src/Tests.Scripts/Tests.Scripts.csproj --nologo
    if ($LASTEXITCODE -ne 0) { Write-Err "Script tests failed"; exit 1 }
    Write-Ok "Script unit tests passed"

    # ── Run plugin tests (FakeXrmEasy) ──
    dotnet test src/Tests.Plugins/Tests.Plugins.csproj --nologo
    if ($LASTEXITCODE -ne 0) { Write-Err "Plugin tests failed"; exit 1 }
    Write-Ok "Plugin unit tests passed"

    # ── Install the unit-tests workflow so both suites run on every PR ──
    $wf = Join-Path $LabRoot ".github/workflows"
    New-Item -ItemType Directory -Path $wf -Force | Out-Null
    Copy-Item "$PSScriptRoot/workflows/unit-tests.yml" $wf -Force
    Write-Ok "Installed unit-tests.yml (runs on every PR; CP12 shows how to make it required)"
} finally { Pop-Location }

Save-Checkpoint -Id "cp14" -Message "Add plugin and script unit test projects with CI workflow" -Body @'
Add the fast layers of the test pyramid so warehouse logic is verified without a Dataverse environment. Plugin logic is covered with FakeXrmEasy and the form/ribbon scripts with Jest against the built web-resource bundle.

## Changes
- add src/Tests.Plugins with FakeXrmEasy tests for both warehouse plugins
- add src/Tests.Scripts with Jest tests for form, ribbon, and grid bridge scripts
- add .github/workflows/unit-tests.yml running both suites on every PR
## Testing
- both suites pass locally via dotnet test 
'@
Write-Host "`n✓ Lab complete — you built, tested and shipped a Power Platform app from source!" -ForegroundColor Green
