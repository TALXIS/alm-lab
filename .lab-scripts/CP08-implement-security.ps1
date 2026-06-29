#!/usr/bin/env pwsh
#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                       CP08: Implement security                                         ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Least-privilege by design: a Security solution with two roles (Warehouse Manager and
# Warehouse Worker) granting scoped privileges over the warehouse tables.
#
# Run:  .lab-scripts/CP08-implement-security.ps1
# ──────────────────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/Lab.Common.ps1"
$PublisherName   = Get-LabValue 'publisherName'   'ALMLab'
$PublisherPrefix = Get-LabValue 'publisherPrefix' 'almlab'

Write-Step "CP08 — Security roles"
Push-Location $LabRoot
try {
    . "$PSScriptRoot/scaffold/04-security.ps1"
    dotnet build --nologo --verbosity quiet
} finally { Pop-Location }

Save-Checkpoint -Id "cp08" -Message "security: 2 roles"
Write-Host "`nNext: .lab-scripts/CP09-implement-ui.ps1" -ForegroundColor Cyan
