import { useEffect, useRef, useState } from "react";
import { BrowserMultiFormatReader } from "@zxing/browser";
import type { IScannerControls } from "@zxing/browser";
import { Almlab_warehouseitemsService } from "@/generated/services/Almlab_warehouseitemsService";
// The generated services expose create/update/get, but no file-column upload - the
// runtime client does, so reach for it directly rather than hand-editing generated code.
import { getClient } from "@microsoft/power-apps/data";
import { dataSourcesInfo } from "../../.power/schemas/appschemas/dataSourcesInfo";
import { Almlab_productsService } from "@/generated/services/Almlab_productsService";
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

// A binary connector response comes back as a base64 string in the JSON envelope, not raw
// bytes - not something the generic executeAsync<TRequest, TResponse> typing can express.
function toBytes(data: unknown): Uint8Array | null {
  if (data instanceof Uint8Array) return data;
  if (data instanceof ArrayBuffer) return new Uint8Array(data);
  if (typeof data === "string") {
    try {
      const binary = atob(data);
      const bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
      return bytes;
    } catch {
      return null;
    }
  }
  return null;
}

// A code app's CSP allows img-src 'self' data: but not blob: - render fetched image bytes as
// a data: URI, not an object URL.
function bytesToDataUrl(bytes: Uint8Array, mimeType: string): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return `data:${mimeType};base64,${btoa(binary)}`;
}

type BarcodeScanDialogProps = {
  itemId: string;
  /** The item's current almlab_productid_value, if it's already linked to a Product. */
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
  const [imageLoading, setImageLoading] = useState(false);
  // The image proxied through the connector for the barcode just looked up: a data: URI for
  // preview, and the bytes it came from so linkProduct() can upload them without re-fetching.
  const [previewImageUrl, setPreviewImageUrl] = useState<string | null>(null);
  const [imageBytes, setImageBytes] = useState<Uint8Array | null>(null);
  // A plain useRef here raced against the dialog's own mount: the decoder could start before
  // the <video> was actually attached, silently handed `undefined` and falling back to zxing's
  // own hidden, unmounted video element - which still decodes fine (explaining barcodes
  // reading correctly) but is never the element on screen (explaining the permanently black
  // rectangle, confirmed across multiple browsers - not a per-browser autoplay quirk). A
  // callback ref (backed by state, so it retriggers the effect) guarantees the effect only
  // ever runs once the real element exists.
  const [videoEl, setVideoEl] = useState<HTMLVideoElement | null>(null);
  const controlsRef = useRef<IScannerControls | null>(null);
  // A camera decode and a manual lookup can resolve in either order - once one of them has
  // already produced a product, a late/stray camera decode (e.g. a misread off a bad frame)
  // must not silently overwrite it.
  const productFoundRef = useRef(false);

  useEffect(() => {
    if (!open || !videoEl) return;
    productFoundRef.current = false;

    // React's `muted` JSX attribute doesn't reliably set the underlying DOM property in every
    // browser; set it directly too, since some autoplay policies check the property.
    videoEl.muted = true;

    const reader = new BrowserMultiFormatReader();
    let cancelled = false;

    reader
      .decodeFromVideoDevice(undefined, videoEl, (result, _err, controls) => {
        controlsRef.current = controls;
        if (cancelled || !result || productFoundRef.current) return;
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
  }, [open, videoEl]);

  const handleEan = async (barcode: string) => {
    if (!barcode) return;
    setLooking(true);
    setProduct(null);
    setImgError(false);
    setPreviewImageUrl(null);
    setImageBytes(null);
    try {
      const result = await OpenFoodFactsService.GetProductByBarcode(barcode);
      if (!result.success || !result.data) {
        toast.error("No product found for this barcode");
        return;
      }
      setProduct(result.data);
      productFoundRef.current = true;
      // The barcode lookup itself is what "Look Up" promises - stop its spinner here and let
      // the (much slower, since it redirects through a different host) image fetch run with
      // its own loading state, so the button doesn't look stuck while the photo comes in.
      setLooking(false);

      if (result.data.imageUrl) {
        // A code app's CSP can block an <img> pointed at an external URL - proxy the bytes
        // through the connector instead, then render them from a data: URI.
        setImageLoading(true);
        try {
          const bytes = await fetchProductImageBytes(result.data.imageUrl);
          if (bytes) {
            setImageBytes(bytes);
            setPreviewImageUrl(bytesToDataUrl(bytes, "image/jpeg"));
          } else {
            setImgError(true);
          }
        } catch {
          // The image is a nice-to-have on top of the product info already surfaced - fall
          // back to the "no image" state rather than failing the whole lookup over it.
          setImgError(true);
        } finally {
          setImageLoading(false);
        }
      }
    } catch (err) {
      toast.error("Lookup failed: " + String(err));
    } finally {
      setLooking(false);
    }
  };

  const fetchProductImageBytes = async (imageUrl: string): Promise<Uint8Array | null> => {
    const result = await OpenFoodFactsService.GetProductImage(imageUrl);
    if (!result.success || !result.data) return null;
    return toBytes(result.data);
  };

  const linkProduct = async () => {
    if (!product || !ean) return;
    setLinking(true);
    try {
      // No alternate key on EAN (see .lab-scripts/scaffold/15-product-table.ps1) - a plain
      // filter-then-create instead of an upsert, so scanning the same barcode twice reuses
      // the existing Product record rather than duplicating it.
      const existing = await Almlab_productsService.getAll({
        select: ["almlab_productid"],
        filter: `almlab_ean eq '${ean}'`,
        top: 1,
      });
      let productId = existing.data?.[0]?.almlab_productid;

      if (!productId) {
        // createRecordAsync's response shape for the new record's id isn't reliable across
        // hosts (confirmed empirically: the live Power Apps player's create response didn't
        // carry almlab_productid in .data) - re-query by the same EAN filter used above
        // instead of trusting the create call's own return value.
        await Almlab_productsService.create({
          almlab_name: product.name || ean,
          almlab_ean: ean,
          almlab_brand: product.brand,
          almlab_quantity: product.quantity,
          almlab_imageurl: product.imageUrl,
          almlab_lastsyncedon: new Date().toISOString(),
        } as any);

        const created = await Almlab_productsService.getAll({
          select: ["almlab_productid"],
          filter: `almlab_ean eq '${ean}'`,
          top: 1,
        });
        productId = created.data?.[0]?.almlab_productid;
      }

      if (!productId) {
        toast.error("Could not resolve a Product record to link");
        return;
      }

      await Almlab_warehouseitemsService.update(itemId, {
        "almlab_productid@odata.bind": `/almlab_products(${productId})`,
      } as any);

      if (imageBytes) {
        try {
          await getClient(dataSourcesInfo).uploadFileToRecord(
            "almlab_products",
            productId,
            "almlab_productimage",
            `${ean}.jpg`,
            imageBytes
          );
        } catch (err) {
          // The product is linked either way - only the photo failed to save, so this is a
          // warning, not a failure of the whole action.
          toast.error("Product linked, but its image failed to save: " + String(err));
        }
      }

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
    setPreviewImageUrl(null);
    setImageBytes(null);
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
              ref={setVideoEl}
              className="w-full rounded-md border bg-black aspect-video"
              muted
              autoPlay
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
                  {imageLoading && (
                    <div className="h-16 w-16 rounded bg-muted flex items-center justify-center shrink-0">
                      <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />
                    </div>
                  )}
                  {previewImageUrl && !imgError && (
                    <img
                      src={previewImageUrl}
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

