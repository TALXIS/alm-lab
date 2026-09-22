#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║              18: Barcode Scan UI — External Data Integration (Step 4)                  ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Adds a "Scan Barcode" button to the item detail page (CP09/scaffold/05f-code-app.ps1). It
# opens a dialog that decodes a barcode with the device camera (@zxing/browser, installed in
# step 3) or accepts one typed in manually, looks it up via the Open Food Facts connector,
# and on confirmation upserts a Product record and links it to the item.
#
# BarcodeScanDialog.tsx is a new, standalone component - not baked into the CP09 template,
# since it depends on the connector wiring that doesn't exist until this checkpoint. The item
# detail page itself, though, already exists in every learner's repo by the time they reach
# CP11 (CP09 created it) - so getting the button onto it means patching the real file in
# place, the same way CP09's own scaffold/09-form-scripts.ps1 patches rollup.config.mjs
# after generating it, rather than trying to re-template the whole page.
#
# Expects: Apps.WarehousePicking's item detail page (CP09) and the OpenFoodFacts connector
# data source (CP11 step 3, scaffold/17-connector-datasource.ps1) already in place.
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Barcode Scan UI ──" -ForegroundColor Cyan

if (-not (Get-LabValue 'barcodeScanUiScaffolded')) {
    $appSrc = "src/Apps.WarehousePicking/src"
    $prefixPascal = [char]::ToUpper($PublisherPrefix[0]) + $PublisherPrefix.Substring(1)
    $uiTokens = @{ PREFIX = $PublisherPrefix; PASCAL = $prefixPascal }

    Expand-LabTemplate -Path "18-barcode-scan-ui/BarcodeScanDialog.tsx" `
        -Destination "$appSrc/components/BarcodeScanDialog.tsx" `
        -Tokens $uiTokens
    Write-Host "  ✓ components/BarcodeScanDialog.tsx" -ForegroundColor Green

    $detailPagePath = "$appSrc/pages/warehouse-item-detail.tsx"
    if (-not (Test-Path $detailPagePath)) {
        Write-Err "$detailPagePath not found - run CP09 first."
        exit 1
    }
    $detailPage = Get-Content $detailPagePath -Raw

    if ($detailPage.Contains("BarcodeScanDialog")) {
        Write-Host "  ✓ warehouse-item-detail.tsx (already wired)" -ForegroundColor Green
    } else {
        $importAnchor = 'import { ArrowLeft, Plus, Package, ArrowRightLeft, MapPin } from "lucide-react";'
        $importReplacement = "$importAnchor`nimport BarcodeScanDialog from `"@/components/BarcodeScanDialog`";"
        $detailPage = $detailPage.Replace($importAnchor, $importReplacement)

        $cardsAnchor = '      <div className="grid gap-4 md:grid-cols-4">'
        $cardsReplacement = @"
      <BarcodeScanDialog
        itemId={id!}
        currentProductId={item._${PublisherPrefix}_productid_value}
        onLinked={() => queryClient.refetchQueries({ queryKey: ["warehouseItem", id] })}
      />

$cardsAnchor
"@
        $detailPage = $detailPage.Replace($cardsAnchor, $cardsReplacement)

        Set-Content -Path $detailPagePath -Value $detailPage -Encoding UTF8 -NoNewline
        Write-Host "  ✓ warehouse-item-detail.tsx (Scan Barcode button wired)" -ForegroundColor Green
    }

    Set-LabValue 'barcodeScanUiScaffolded' $true
} else {
    Write-Host "  ✓ Barcode Scan UI (exists)" -ForegroundColor Green
}

Write-Host "  ℹ Local preview: cd src/Apps.WarehousePicking && npm run dev" -ForegroundColor DarkGray
