#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║                            18: Barcode Scan UI                                         ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Adds a "Scan Barcode" button to the item detail page (CP09). It opens a dialog that decodes
# a barcode with the device camera (@zxing/browser) or accepts one typed in manually, looks
# it up via the connector, and on confirmation upserts a Product record, links it to the item,
# and shows its image (once linked) via a new LinkedProductImage component.
#
# Both components are new, standalone files, patched onto the existing item detail page rather
# than baked into the CP09 template, since they depend on connector wiring that doesn't exist
# until this checkpoint.
#
# Expects: Apps.WarehousePicking's item detail page (CP09) and the connector data source
# (step 3, scaffold/17-connector-datasource.ps1) already in place.
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

    Expand-LabTemplate -Path "18-barcode-scan-ui/LinkedProductImage.tsx" `
        -Destination "$appSrc/components/LinkedProductImage.tsx" `
        -Tokens $uiTokens
    Write-Host "  ✓ components/LinkedProductImage.tsx" -ForegroundColor Green

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
        $importReplacement = @"
$importAnchor
import BarcodeScanDialog from "@/components/BarcodeScanDialog";
import LinkedProductImage from "@/components/LinkedProductImage";
import { ${prefixPascal}_productsService } from "@/generated/services/${prefixPascal}_productsService";
"@
        $detailPage = $detailPage.Replace($importAnchor, $importReplacement)

        # The linked-product lookup is a hook, so it has to run on every render alongside the
        # page's other hooks - it can't be declared further down next to the JSX that uses it,
        # since that JSX sits after the itemLoading/!item early returns.
        $mutationAnchor = '  const createTxMutation = useMutation({'
        $mutationReplacement = @"
  const linkedProductId = item?._${PublisherPrefix}_productid_value;
  const { data: linkedProduct } = useQuery({
    queryKey: ["linkedProduct", linkedProductId],
    queryFn: async () => {
      const result = await ${prefixPascal}_productsService.get(linkedProductId!);
      return result.data;
    },
    enabled: !!linkedProductId,
  });

$mutationAnchor
"@
        $detailPage = $detailPage.Replace($mutationAnchor, $mutationReplacement)

        $cardsAnchor = '      <div className="grid gap-4 md:grid-cols-4">'
        $cardsReplacement = @"
      <div className="flex items-center justify-between">
        <BarcodeScanDialog
          itemId={id!}
          currentProductId={linkedProductId}
          onLinked={() => queryClient.refetchQueries({ queryKey: ["warehouseItem", id] })}
        />
        {linkedProduct && (
          <div className="flex items-center gap-2 text-sm" data-testid="linked-product-name">
            <LinkedProductImage productId={linkedProductId!} />
            <span className="text-muted-foreground">Linked product:</span>
            <span className="font-medium">{linkedProduct.${PublisherPrefix}_name}</span>
          </div>
        )}
      </div>

$cardsAnchor
"@
        $detailPage = $detailPage.Replace($cardsAnchor, $cardsReplacement)

        Set-Content -Path $detailPagePath -Value $detailPage -Encoding UTF8 -NoNewline
        Write-Host "  ✓ warehouse-item-detail.tsx (Scan Barcode button + linked product wired)" -ForegroundColor Green
    }

    Set-LabValue 'barcodeScanUiScaffolded' $true
} else {
    Write-Host "  ✓ Barcode Scan UI (exists)" -ForegroundColor Green
}

Write-Host "  ℹ Local preview: cd src/Apps.WarehousePicking && npm run dev" -ForegroundColor DarkGray
