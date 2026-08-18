#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║             09: Form Scripts — Script Library, TypeScript, Event Handlers              ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Creates a Script Library project (TypeScript → JS web resource) and registers
# form event handlers on the warehouse transaction form.
# Expects: $PublisherPrefix, $warehousetransactionFormGuid from parent scope.
#
# ──────────────────────────────────────────────────────────────────────────────────────────
#                              Script Library Project
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Scripts.UI ──" -ForegroundColor Cyan

txc workspace component create pp-script-library `
    --param "LibraryName=main" `
    --param "PublisherPrefix=$PublisherPrefix" `
    --output "src/Scripts.UI"

dotnet sln add src/Scripts.UI

Write-Host "  ✓ Scripts.UI project (TypeScript → JS)" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                              TypeScript Source Files
# ──────────────────────────────────────────────────────────────────────────────────────────

# Form handlers — written to src/index.ts which is the rollup entry point.
# The UMD global name in rollup.config.mjs must be "WarehouseScripts" so the
# form event handlers can resolve WarehouseScripts.TransactionForm.onLoad etc.
# Full source: .lab-scripts/templates/09-form-scripts/index.ts
Expand-LabTemplate -Path "09-form-scripts/index.ts" `
    -Destination "src/Scripts.UI/src/index.ts" `
    -Tokens @{ PREFIX = $PublisherPrefix }
Write-Host "  ✓ src/index.ts (TransactionForm + RibbonActions)" -ForegroundColor Green

# Update rollup UMD name to match the namespace expected by form event handlers
$rollupConfig = Get-Content "src/Scripts.UI/rollup.config.mjs" -Raw
$rollupConfig = $rollupConfig -replace "name: '${PublisherPrefix}_main'", "name: 'WarehouseScripts'"
Set-Content -Path "src/Scripts.UI/rollup.config.mjs" -Value $rollupConfig -Encoding UTF8
Write-Host "  ✓ rollup.config.mjs (UMD name → WarehouseScripts)" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                         Link Script Library to UI Solution
# ──────────────────────────────────────────────────────────────────────────────────────────

cd src/Solutions.UI
dotnet add reference ../Scripts.UI/Scripts.UI.csproj
cd ../..

Write-Host "  ✓ ProjectReference: Scripts.UI → Solutions.UI" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                              Build Script Library
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "  → Building Scripts.UI..." -ForegroundColor White
cd src/Scripts.UI
dotnet build --nologo --verbosity quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Scripts build succeeded" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Scripts build had issues (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
}
cd ../..

# ──────────────────────────────────────────────────────────────────────────────────────────
#                              Form Event Handlers
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Form Event Handlers ──" -ForegroundColor Cyan

# OnLoad handler on warehouse transaction form
txc workspace component create pp-form-event-handler `
    --output "src/Solutions.UI" `
    --param "FormType=main" `
    --param "FormId=$warehousetransactionFormGuid" `
    --param "EntityLogicalName=${PublisherPrefix}_warehousetransaction" `
    --param "LibraryName=${PublisherPrefix}_main" `
    --param "FunctionName=WarehouseScripts.TransactionForm.onLoad" `
    --param "EventType=onload"

Write-Host "  ✓ Event handler: warehousetransaction form → onLoad" -ForegroundColor Green

# OnChange handler on quantity field
txc workspace component create pp-form-event-handler `
    --output "src/Solutions.UI" `
    --param "FormType=main" `
    --param "FormId=$warehousetransactionFormGuid" `
    --param "EntityLogicalName=${PublisherPrefix}_warehousetransaction" `
    --param "LibraryName=${PublisherPrefix}_main" `
    --param "FunctionName=WarehouseScripts.TransactionForm.onQuantityChange" `
    --param "EventType=onchange" `
    --param "AttributeName=${PublisherPrefix}_quantity"

Write-Host "  ✓ Event handler: warehousetransaction quantity → onChange" -ForegroundColor Green
