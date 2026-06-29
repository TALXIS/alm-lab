#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP02: Create repository layout                                   ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# A Power Platform project is best managed as a monorepo: plugins, scripts, PCFs, connectors
# and solution components live under one Git repo. MSBuild (dotnet build) orchestrates the
# whole build. We create:
#   - a Visual Studio solution file (.slnx) to track all projects
#   - NuGet.config pointing at nuget.org for TALXIS DevKit packages
#   - a src/ folder where solutions and code projects will live
#
# We deliberately keep this empty now — checkpoints CP06–CP09 fill it in component by
# component, exactly like real development.
#
# Run:  .lab-scripts/CP02-create-repository-layout.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"

Write-Step "CP02 — Repository layout"

Push-Location $LabRoot
try {
    $solutionName = "WarehouseManagement"
    Set-LabValue 'solutionName'   $solutionName
    Set-LabValue 'publisherName'   "ALMLab"
    Set-LabValue 'publisherPrefix' "almlab"

    # Step 1: NuGet feed (TALXIS DevKit build SDK + templates come from nuget.org)
    @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
  </packageSources>
</configuration>
'@ | Set-Content -Path "NuGet.config" -Encoding UTF8
    Write-Ok "NuGet.config"

    # Step 2: Visual Studio solution (modern .slnx) to track all projects in the monorepo
    if (-not (Test-Path "$solutionName.slnx")) {
        dotnet new sln --name $solutionName | Out-Null
        if (Test-Path "$solutionName.sln") {
            dotnet sln "$solutionName.sln" migrate | Out-Null
            Remove-Item "$solutionName.sln" -ErrorAction SilentlyContinue
        }
        Write-Ok "$solutionName.slnx"
    } else {
        Write-Ok "$solutionName.slnx (exists)"
    }

    # Step 3: src/ — home for solution and code projects
    if (-not (Test-Path "src")) { New-Item -ItemType Directory -Path "src" | Out-Null }
    New-Item -ItemType File -Path "src/.gitkeep" -Force | Out-Null
    Write-Ok "src/ directory"
}
finally { Pop-Location }

Save-Checkpoint -Id "cp02" -Message "create monorepo layout (slnx, NuGet.config, src)"
Write-Host "`nNext: .lab-scripts/CP03-setup-continuous-integration.ps1" -ForegroundColor Cyan
