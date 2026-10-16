import type { HostEntity } from "@/providers/pcf-host";

// The warehouse tables as TALXIS base controls see them (registered in router.tsx): lookups read
// their metadata, grids their primary columns, and items open on their detail page.
export const warehouseEntities: HostEntity[] = [
  {
    logicalName: "__PREFIX___warehouseitem",
    displayName: "Warehouse Item",
    primaryIdAttribute: "__PREFIX___warehouseitemid",
    primaryNameAttribute: "__PREFIX___name",
    formPath: (id) => `/items/${id}`,
  },
  {
    logicalName: "__PREFIX___warehouselocation",
    displayName: "Location",
    primaryIdAttribute: "__PREFIX___warehouselocationid",
    primaryNameAttribute: "__PREFIX___name",
  },
  {
    logicalName: "__PREFIX___warehousetransaction",
    displayName: "Warehouse Transaction",
    primaryIdAttribute: "__PREFIX___warehousetransactionid",
    primaryNameAttribute: "__PREFIX___name",
  },
];
