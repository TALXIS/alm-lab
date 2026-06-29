#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP07: Implement backend                                          ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Server-side logic: a plugin project (validates transactions, subtracts stock) and the
# Logic solution that registers the SDK message processing steps. Plugins are C#, compiled
# by dotnet build and packaged for deployment.
#
# Run:  .lab-scripts/CP07-implement-backend.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$PublisherName   = Get-LabValue 'publisherName'   'ALMLab'
$PublisherPrefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP07 — Backend (plugins + logic)"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/07-plugins.ps1"
    . "$PSScriptRoot/scaffold/08-logic-solution.ps1"
    dotnet build --nologo --verbosity quiet
} finally { Pop-Location }

Save-Checkpoint -Id "cp07" -Message "backend: plugins + logic solution"
Write-Host "`nNext: .lab-scripts/CP08-implement-security.ps1" -ForegroundColor Cyan
