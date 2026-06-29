#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                         03a: Package Deployer (Packages.Main)                          ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Creates the Package Deployer project that deploys all solutions.
# Expects: $PublisherName, $PublisherPrefix from parent scope.
#
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Package Deployer ──" -ForegroundColor Cyan

txc workspace component create pp-package `
    --output "src/Packages.Main"

# Add the package project to the Visual Studio solution file (run from repo root)
dotnet sln add src/Packages.Main/Packages.Main.csproj

Write-Host "  ✓ Packages.Main" -ForegroundColor Green
