#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║           05f: Code App Solution — Dedicated Solution for the Code App                 ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Creates Solutions.CodeApp — a Dataverse solution project whose only job is to carry the
# warehouse code app. A code app ships as a CanvasApp component, so it needs a solution to
# live in; the DevKit solution build registers and packs the built app automatically.
# Expects: $PublisherName, $PublisherPrefix from parent scope.
#
# ──────────────────────────────────────────────────────────────────────────────────────────
#                                  Solutions.CodeApp
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Solutions.CodeApp ──" -ForegroundColor Cyan

txc workspace component create pp-solution `
    --output "src/Solutions.CodeApp" `
    --param "PublisherName=$PublisherName" `
    --param "PublisherPrefix=$PublisherPrefix"
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ Solutions.CodeApp scaffold failed" -ForegroundColor Red; exit 1 }

Write-Host "  ✓ Solutions.CodeApp" -ForegroundColor Green

# Add Solutions.CodeApp to the Package Deployer project as a .NET ProjectReference
dotnet add "src/Packages.Main/Packages.Main.csproj" reference "src/Solutions.CodeApp/Solutions.CodeApp.csproj"
if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ ProjectReference CodeApp → Packages.Main failed" -ForegroundColor Red; exit 1 }

Write-Host "  ✓ ProjectReference: CodeApp → Packages.Main" -ForegroundColor Green
