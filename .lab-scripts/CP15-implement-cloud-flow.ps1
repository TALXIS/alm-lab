#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP15: Implement a cloud flow                                     ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# The low-code half of the automation story. CP07 added pro-code server logic: C# plugins
# compiled by dotnet build, registered through SDK message processing steps. This checkpoint
# adds a Power Automate cloud flow to the same Logic solution - and treats it exactly like
# every other component in this repo. It is scaffolded from a template, it lives in source,
# it goes through a PR, and it deploys with the solution. Nobody opens the designer.
#
# That last part is the reason this checkpoint exists. A flow definition is hand-written
# JSON with no compiler behind it. Nothing stops you writing an operation that does not
# exist, a parameter name that is close but wrong, or the wrong action type - and none of
# it surfaces until a deployment fails or, worse, until the flow silently never runs. It is
# the easiest place in this whole repo to write something plausible and broken.
#
# So the flow is not written from memory. The scaffold script reads the connector contract
# out of your Dev environment first:
#
#   txc environment connector get       <connector> --query "list rows"
#   txc environment connector operation get <connector> ListRecords
#
# and then checks the finished definition back against that same metadata:
#
#   txc environment flow validate src/Solutions.Logic/Workflows --connection-check
#
# Read the printed parameter contract before you read the JSON. Every name in the action
# came from it.
#
# One honest gap: a solution-aware flow binds to a *connection reference*, and there is no
# component template for one yet, so it cannot be scaffolded from source like everything
# else. The scaffold checks that one exists and tells you how to create it if not.
#
# Run:  .lab-scripts/CP15-implement-cloud-flow.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$PublisherName   = Get-LabValue 'publisherName'   'ALMLab'
$PublisherPrefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP15 — Cloud flow (low-code automation from source)"
Push-Location $LabRoot
try {
    if (-not (Test-Path "src/Solutions.Logic/Solutions.Logic.csproj")) {
        Write-Err "Solutions.Logic not found — run .lab-scripts/CP07-implement-backend.ps1 first"
        exit 1
    }

    . "$PSScriptRoot/scaffold/15-cloud-flow.ps1"

    # The flow is packed into the solution like any other component, so a bad definition or
    # a filename that does not match the Workflow record breaks the build here, not at deploy.
    dotnet build --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) { Write-Err "dotnet build failed"; exit 1 }
} finally { Pop-Location }

Save-Checkpoint -Id "cp15" -Message "Add a cloud flow validated against connector metadata" -Body @'
Add low-code automation to the Logic solution as a source-controlled component. The flow is scaffolded from a template, its Dataverse action is filled in from connector metadata read out of the connected environment, and the finished definition is checked back against that metadata before it is allowed to build.

## Changes
- add a cloud flow to src/Solutions.Logic that lists warehouse items below a stock threshold
- read the operation contract from the environment instead of hand-writing parameter names
- gate the checkpoint on txc environment flow validate --connection-check

## Testing
- txc environment flow validate reports no findings against the Dev environment
- dotnet build --nologo --verbosity quiet packs the solution with the flow included
'@
Write-Host "`n✓ Lab complete — you built, tested and shipped a Power Platform app from source!" -ForegroundColor Green
