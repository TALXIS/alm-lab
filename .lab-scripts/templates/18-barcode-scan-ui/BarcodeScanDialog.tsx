import { useEffect, useRef, useState } from "react";
import { BrowserMultiFormatReader } from "@zxing/browser";
import type { IScannerControls } from "@zxing/browser";
import { __PASCAL___warehouseitemsService } from "@/generated/services/__PASCAL___warehouseitemsService";
import { __PASCAL___productsService } from "@/generated/services/__PASCAL___productsService";
import { OpenFoodFactsService } from "@/generated/services/OpenFoodFactsService";
import type { Product } from "@/generated/models/OpenFoodFactsModel";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Card, CardContent } from "@/components/ui/card";
import { toast } from "sonner";
import { ScanLine, Loader2 } from "lucide-react";

type BarcodeScanDialogProps = {
  itemId: string;
  /** The item's current __PREFIX___productid_value, if it's already linked to a Product. */
  currentProductId?: string;
  onLinked: () => void;
};

// A camera scan and a manually-typed EAN both end up going through the same handleEan path -
// there's exactly one place that decides what a barcode means. The manual input is also the
// only way to drive this in CI/Playwright, which has no camera: see 18-tests-ui for how the
// test hook types into #scanEan and clicks #scanLookupButton directly, skipping the camera.
export default function BarcodeScanDialog({ itemId, currentProductId, onLinked }: BarcodeScanDialogProps) {
  const [open, setOpen] = useState(false);
  const [ean, setEan] = useState("");
  const [looking, setLooking] = useState(false);
  const [linking, setLinking] = useState(false);
  const [product, setProduct] = useState<Product | null>(null);
  const [imgError, setImgError] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);
  const controlsRef = useRef<IScannerControls | null>(null);

  useEffect(() => {
    if (!open) return;

    const reader = new BrowserMultiFormatReader();
    let cancelled = false;

    reader
      .decodeFromVideoDevice(undefined, videoRef.current ?? undefined, (result, _err, controls) => {
        controlsRef.current = controls;
        if (cancelled || !result) return;
        const text = result.getText();
        controls.stop();
        setEan(text);
        void handleEan(text);
      })
      .catch(() => {
        // No camera available (headless CI, permission denied, no device) - not an error
        // worth surfacing, the manual EAN input below is the fallback either way.
      });

    return () => {
      cancelled = true;
      controlsRef.current?.stop();
      controlsRef.current = null;
    };
  }, [open]);

  const handleEan = async (barcode: string) => {
    if (!barcode) return;
    setLooking(true);
    setProduct(null);
    setImgError(false);
    try {
      const result = await OpenFoodFactsService.GetProductByBarcode(barcode);
      if (!result.success || !result.data) {
        toast.error("No product found for this barcode");
        return;
      }
      setProduct(result.data);
    } catch (err) {
      toast.error("Lookup failed: " + String(err));
    } finally {
      setLooking(false);
    }
  };

  const linkProduct = async () => {
    if (!product || !ean) return;
    setLinking(true);
    try {
      // No alternate key on EAN (see .lab-scripts/scaffold/15-product-table.ps1) - a plain
      // filter-then-create instead of an upsert, so scanning the same barcode twice reuses
      // the existing Product record rather than duplicating it.
      const existing = await __PASCAL___productsService.getAll({
        select: ["__PREFIX___productid"],
        filter: `__PREFIX___ean eq '${ean}'`,
        top: 1,
      });
      let productId = existing.data?.[0]?.__PREFIX___productid;

      if (!productId) {
        // createRecordAsync's response shape for the new record's id isn't reliable across
        // hosts (confirmed empirically: the live Power Apps player's create response didn't
        // carry __PREFIX___productid in .data) - re-query by the same EAN filter used above
        // instead of trusting the create call's own return value.
        await __PASCAL___productsService.create({
          __PREFIX___name: product.name || ean,
          __PREFIX___ean: ean,
          __PREFIX___brand: product.brand,
          __PREFIX___quantity: product.quantity,
          __PREFIX___imageurl: product.imageUrl,
          __PREFIX___lastsyncedon: new Date().toISOString(),
        } as any);

        const created = await __PASCAL___productsService.getAll({
          select: ["__PREFIX___productid"],
          filter: `__PREFIX___ean eq '${ean}'`,
          top: 1,
        });
        productId = created.data?.[0]?.__PREFIX___productid;
      }

      if (!productId) {
        toast.error("Could not resolve a Product record to link");
        return;
      }

      await __PASCAL___warehouseitemsService.update(itemId, {
        "__PREFIX___productid@odata.bind": `/__PREFIX___products(${productId})`,
      } as any);

      toast.success("Product linked to item");
      onLinked();
      resetAndClose();
    } catch (err) {
      toast.error("Failed to link product: " + String(err));
    } finally {
      setLinking(false);
    }
  };

  const resetAndClose = () => {
    setOpen(false);
    setEan("");
    setProduct(null);
  };

  return (
    <>
      <Button
        variant="outline"
        size="sm"
        data-testid="scan-barcode-button"
        onClick={() => setOpen(true)}
      >
        <ScanLine className="h-4 w-4 mr-2" />
        {currentProductId ? "Rescan Barcode" : "Scan Barcode"}
      </Button>

      <Dialog open={open} onOpenChange={(next) => (next ? setOpen(true) : resetAndClose())}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Scan Product Barcode</DialogTitle>
          </DialogHeader>

          <div className="space-y-4">
            <video
              ref={videoRef}
              className="w-full rounded-md border bg-black aspect-video"
              muted
              playsInline
            />

            <div className="space-y-2">
              <Label htmlFor="scanEan">EAN / UPC barcode</Label>
              <div className="flex gap-2">
                <Input
                  id="scanEan"
                  data-testid="scan-ean-input"
                  value={ean}
                  onChange={(e) => setEan(e.target.value)}
                  placeholder="e.g. 3017620422003"
                />
                <Button
                  type="button"
                  data-testid="scan-lookup-button"
                  disabled={!ean || looking}
                  onClick={() => void handleEan(ean)}
                >
                  {looking ? <Loader2 className="h-4 w-4 animate-spin" /> : "Look Up"}
                </Button>
              </div>
            </div>

            {product && (
              <Card>
                <CardContent className="pt-4 flex items-center gap-4">
                  {product.imageUrl && !imgError && (
                    <img
                      src={product.imageUrl}
                      alt={product.name ?? ean}
                      className="h-16 w-16 object-contain rounded"
                      onError={() => setImgError(true)}
                    />
                  )}
                  <div>
                    <div className="font-medium" data-testid="scan-product-name">
                      {product.name ?? "Unknown product"}
                    </div>
                    <div className="text-sm text-muted-foreground">
                      {[product.brand, product.quantity].filter(Boolean).join(" · ")}
                    </div>
                  </div>
                </CardContent>
              </Card>
            )}
          </div>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={resetAndClose}>
              Cancel
            </Button>
            <Button
              type="button"
              data-testid="scan-link-button"
              disabled={!product || linking}
              onClick={() => void linkProduct()}
            >
              {linking ? <Loader2 className="h-4 w-4 animate-spin" /> : "Link to Item"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
