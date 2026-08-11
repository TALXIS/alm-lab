import { useQuery } from "@tanstack/react-query"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table"
import { __PREFIX_PASCAL___warehouseitemsService } from "@/generated/services/__PREFIX_PASCAL___warehouseitemsService"
import { __PREFIX_PASCAL___warehouselocationsService } from "@/generated/services/__PREFIX_PASCAL___warehouselocationsService"

export default function LocationsPage() {
  const locationsQuery = useQuery({
    queryKey: ["warehouseLocations"],
    queryFn: async () => {
      const result = await __PREFIX_PASCAL___warehouselocationsService.getAll({ orderBy: ["__PREFIX___name asc"] })
      if (!result.success) throw new Error(result.error?.message ?? "Failed to load warehouse locations")
      return result.data
    },
  })

  const itemsQuery = useQuery({
    queryKey: ["warehouseItems"],
    queryFn: async () => {
      const result = await __PREFIX_PASCAL___warehouseitemsService.getAll({
        select: ["__PREFIX___warehouseitemid", "__PREFIX___availablequantity", "___PREFIX___locationid_value"],
      })
      if (!result.success) throw new Error(result.error?.message ?? "Failed to load warehouse items")
      return result.data
    },
  })

  const isLoading = locationsQuery.isLoading || itemsQuery.isLoading
  const error = (locationsQuery.error ?? itemsQuery.error) as Error | null

  return (
    <div className="py-8 space-y-6">
      <h1 className="text-2xl font-semibold">Locations</h1>

      {error && <p className="text-sm text-destructive">Failed to load locations: {error.message}</p>}

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Address</TableHead>
            <TableHead className="text-right">Capacity</TableHead>
            <TableHead className="text-right">Items</TableHead>
            <TableHead className="text-right">Qty on hand</TableHead>
            <TableHead>Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {isLoading && Array.from({ length: 2 }).map((_, i) => (
            <TableRow key={i}>
              {Array.from({ length: 6 }).map((__, j) => <TableCell key={j}><Skeleton className="h-4 w-full" /></TableCell>)}
            </TableRow>
          ))}
          {!isLoading && locationsQuery.data?.length === 0 && (
            <TableRow><TableCell colSpan={6} className="text-center text-muted-foreground">No locations yet.</TableCell></TableRow>
          )}
          {!isLoading && locationsQuery.data?.map((location) => {
            const itemsHere = itemsQuery.data?.filter((item) => item.___PREFIX___locationid_value === location.__PREFIX___warehouselocationid) ?? []
            const totalQty = itemsHere.reduce((sum, item) => sum + Number(item.__PREFIX___availablequantity ?? 0), 0)
            return (
              <TableRow key={location.__PREFIX___warehouselocationid} data-testid="location-row">
                <TableCell className="font-medium">{location.__PREFIX___name}</TableCell>
                <TableCell>{location.__PREFIX___address ?? "—"}</TableCell>
                <TableCell className="text-right">{location.__PREFIX___capacity ?? "—"}</TableCell>
                <TableCell className="text-right">{itemsHere.length}</TableCell>
                <TableCell className="text-right">{totalQty}</TableCell>
                <TableCell>
                  <Badge variant={location.__PREFIX___isactive ? "default" : "secondary"}>
                    {location.__PREFIX___isactive ? "Active" : "Inactive"}
                  </Badge>
                </TableCell>
              </TableRow>
            )
          })}
        </TableBody>
      </Table>
    </div>
  )
}
