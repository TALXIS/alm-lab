#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                      10: Ribbon Buttons — Custom Ribbon Commands                       ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Adds custom ribbon buttons to entity forms and home pages.
# Expects: $PublisherPrefix from parent scope.
# Expects: Scripts.UI already built (09-form-scripts.ps1).
#
# ──────────────────────────────────────────────────────────────────────────────────────────
#                              TypeScript for Ribbon Actions
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Ribbon Buttons ──" -ForegroundColor Cyan

# Add ribbon action TypeScript file
# Full source: .lab-scripts/templates/10-ribbon/RibbonActions.ts
Expand-LabTemplate -Path "10-ribbon/RibbonActions.ts" `
    -Destination "src/Scripts.UI/src/RibbonActions.ts" `
    -Tokens @{ PREFIX = $PublisherPrefix }
Write-Host "  ✓ RibbonActions.ts" -ForegroundColor Green

# Rebuild Scripts.UI with the new file
Write-Host "  → Rebuilding Scripts.UI..." -ForegroundColor White
cd src/Scripts.UI
dotnet build --nologo --verbosity quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Scripts rebuild succeeded" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Scripts rebuild had issues (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
}
cd ../..

# ──────────────────────────────────────────────────────────────────────────────────────────
#                      Ribbon Button: Check Stock Levels (warehouseitem form)
# ──────────────────────────────────────────────────────────────────────────────────────────

txc workspace component create pp-ribbon-button `
    --output "src/Solutions.UI" `
    --param "Location=Form" `
    --param "EntityLogicalName=${PublisherPrefix}_warehouseitem" `
    --param "ButtonLabel=Check Stock Levels" `
    --param "PublisherPrefix=$PublisherPrefix" `
    --param "LibraryLogicalName=${PublisherPrefix}_main.js" `
    --param "FunctionName=WarehouseScripts.RibbonActions.checkStockLevels" `
    --param "Sequence=31" `
    --param "TemplateAlias=o1"

Write-Host "  ✓ Ribbon button: Check Stock Levels (warehouseitem form)" -ForegroundColor Green

# Add PrimaryControl parameter so the function receives the form context
txc workspace component create pp-ribbon-command-parameter `
    --output "src/Solutions.UI" `
    --param "EntityLogicalName=${PublisherPrefix}_warehouseitem" `
    --param "PublisherPrefix=$PublisherPrefix" `
    --param "ParameterType=CrmPrimaryControl" `
    --param "FunctionName=WarehouseScripts.RibbonActions.checkStockLevels" `
    --param "ButtonLogicalName=checkstocklevels"

Write-Host "  ✓ Ribbon command parameter: PrimaryControl" -ForegroundColor Green
