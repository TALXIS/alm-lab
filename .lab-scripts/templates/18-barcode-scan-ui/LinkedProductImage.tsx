import { useEffect, useState } from "react";
import { getClient } from "@microsoft/power-apps/data";
import { dataSourcesInfo } from "../../.power/schemas/appschemas/dataSourcesInfo";
import { bytesToDataUrl } from "@/utils/binary";

const client = getClient(dataSourcesInfo);

type LinkedProductImageProps = {
  productId: string;
};

// No generated service method downloads a file column's bytes - only upload() is generated -
// so this goes through the low-level client directly, the same one the generated services
// themselves are built on.
export default function LinkedProductImage({ productId }: LinkedProductImageProps) {
  const [imageUrl, setImageUrl] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setImageUrl(null);

    client
      .downloadFileFromRecord("__PREFIX___products", productId, "__PREFIX___productimage")
      .then((result) => {
        if (cancelled || !result.success || !result.data?.length) return;
        setImageUrl(bytesToDataUrl(result.data, "image/jpeg"));
      });

    return () => {
      cancelled = true;
    };
  }, [productId]);

  if (!imageUrl) return null;

  return (
    <img
      src={imageUrl}
      alt=""
      className="h-8 w-8 object-contain rounded"
      onError={() => setImageUrl(null)}
    />
  );
}
