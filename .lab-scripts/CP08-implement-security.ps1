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

Save-Checkpoint -Id "cp08" -Message "Add warehouse security roles and entity privileges" -Body @'
Define security boundaries for the warehouse app so workers and managers get the access they need. This checkpoint adds a dedicated security solution and the role privileges required for day-to-day operations.

## Changes
- add src/Solutions.Security to package security configuration as code
- create Warehouse worker and Warehouse manager security roles
- assign entity privileges for locations, items, and transactions
## Testing
- dotnet build --nologo --verbosity quiet passes after adding the security solution
'@
Write-Host "`nNext: .lab-scripts/CP09-implement-ui.ps1" -ForegroundColor Cyan
