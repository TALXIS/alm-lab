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

if (-not (Get-LabValue 'packageDeployerScaffolded')) {
    txc workspace component create pp-package `
        --output "src/Packages.Main"

    # Add the package project to the Visual Studio solution file (run from repo root)
    dotnet sln add src/Packages.Main/Packages.Main.csproj

    # Marks the whole block done — checked instead of Test-Path on the csproj so a re-run
    # after a partial failure (e.g. sln add succeeded, something after it didn't) retries
    # everything rather than silently skipping past a half-finished project.
    Set-LabValue 'packageDeployerScaffolded' $true
    Write-Host "  ✓ Packages.Main" -ForegroundColor Green
} else {
    Write-Host "  ✓ Packages.Main (exists)" -ForegroundColor Green
}
