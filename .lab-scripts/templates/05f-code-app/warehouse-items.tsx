import { useState } from "react"
import { Link } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import { Plus, RefreshCw } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Skeleton } from "@/components/ui/skeleton"
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table"
import {
  Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle, DialogTrigger,
} from "@/components/ui/dialog"
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select"
import { __PREFIX_PASCAL___warehouseitemsService } from "@/generated/services/__PREFIX_PASCAL___warehouseitemsService"
import { __PREFIX_PASCAL___warehouselocationsService } from "@/generated/services/__PREFIX_PASCAL___warehouselocationsService"
import type { __PREFIX_PASCAL___warehouseitems__PREFIX___category } from "@/generated/models/__PREFIX_PASCAL___warehouseitemsModel"
import { categoryOptions, formatCurrency, isLowStock } from "@/utils/optionSets"

const emptyForm = { name: "", sku: "", category: "", locationId: "", availableQuantity: "0", unitPrice: "" }

export default function WarehouseItemsPage() {
  const queryClient = useQueryClient()
  const [open, setOpen] = useState(false)
  const [form, setForm] = useState(emptyForm)

  const itemsQuery = useQuery({
    queryKey: ["warehouseItems"],
    queryFn: async () => {
      const result = await __PREFIX_PASCAL___warehouseitemsService.getAll({ orderBy: ["__PREFIX___name asc"] })
      if (!result.success) throw new Error(result.error?.message ?? "Failed to load warehouse items")
      return result.data
    },
  })

  const locationsQuery = useQuery({
    queryKey: ["warehouseLocations"],
    queryFn: async () => {
      const result = await __PREFIX_PASCAL___warehouselocationsService.getAll({ orderBy: ["__PREFIX___name asc"] })
      if (!result.success) throw new Error(result.error?.message ?? "Failed to load warehouse locations")
      return result.data
    },
  })

  const createItem = useMutation({
    mutationFn: async () => {
      const result = await __PREFIX_PASCAL___warehouseitemsService.create({
        __PREFIX___name: form.name,
        __PREFIX___sku: form.sku,
        __PREFIX___category: form.category ? (Number(form.category) as __PREFIX_PASCAL___warehouseitems__PREFIX___category) : undefined,
        __PREFIX___availablequantity: String(form.availableQuantity || "0"),
        __PREFIX___unitprice: form.unitPrice ? String(form.unitPrice) : undefined,
        ...(form.locationId ? { "__PREFIX___locationid@odata.bind": `/__PREFIX___warehouselocations(${form.locationId})` } : {}),
        // ownerid/owneridtype/statecode are typed as required on Base (true for reads — every
        // record has an owner/state), but Dataverse defaults all three on create; the cast below
        // only suppresses that "missing property" mismatch, it still catches real typos/type
        // errors in the fields we do pass.
      } as Parameters<typeof __PREFIX_PASCAL___warehouseitemsService.create>[0])
      if (!result.success) throw new Error(result.error?.message ?? "Failed to create warehouse item")
      return result.data
    },
    onSuccess: () => {
      toast.success("Warehouse item created")
      queryClient.invalidateQueries({ queryKey: ["warehouseItems"] })
      setForm(emptyForm)
      setOpen(false)
    },
    onError: (error: Error) => toast.error(error.message),
  })

  return (
    <div className="py-8 space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Warehouse Items</h1>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="icon"
            data-testid="refresh-items"
            onClick={() => queryClient.invalidateQueries({ queryKey: ["warehouseItems"] })}
          >
            <RefreshCw className="h-4 w-4" />
          </Button>
          <Dialog open={open} onOpenChange={(next) => { setOpen(next); if (!next) setForm(emptyForm) }}>
            <DialogTrigger asChild>
              <Button data-testid="new-item-button"><Plus className="h-4 w-4 mr-2" />New Item</Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader><DialogTitle>New Warehouse Item</DialogTitle></DialogHeader>
              <form
                className="space-y-4"
                onSubmit={(e) => { e.preventDefault(); createItem.mutate() }}
              >
                <div className="space-y-2">
                  <Label htmlFor="item-name">Name</Label>
                  <Input id="item-name" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="item-sku">SKU</Label>
                  <Input id="item-sku" required value={form.sku} onChange={(e) => setForm({ ...form, sku: e.target.value })} />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="item-category">Category</Label>
                  <Select value={form.category} onValueChange={(value) => setForm({ ...form, category: value })}>
                    <SelectTrigger id="item-category"><SelectValue placeholder="Select a category" /></SelectTrigger>
                    <SelectContent>
                      {categoryOptions.map((option) => (
                        <SelectItem key={option.value} value={String(option.value)}>{option.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="item-location">Location</Label>
                  <Select value={form.locationId} onValueChange={(value) => setForm({ ...form, locationId: value })}>
                    <SelectTrigger id="item-location"><SelectValue placeholder="No location" /></SelectTrigger>
                    <SelectContent>
                      {locationsQuery.data?.map((location) => (
                        <SelectItem key={location.__PREFIX___warehouselocationid} value={location.__PREFIX___warehouselocationid}>
                          {location.__PREFIX___name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="item-qty">Available Quantity</Label>
                    <Input
                      id="item-qty" type="number" min="0" required
                      value={form.availableQuantity}
                      onChange={(e) => setForm({ ...form, availableQuantity: e.target.value })}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="item-price">Unit Price</Label>
                    <Input
                      id="item-price" type="number" min="0" step="0.01"
                      value={form.unitPrice}
                      onChange={(e) => setForm({ ...form, unitPrice: e.target.value })}
                    />
                  </div>
                </div>
                <DialogFooter>
                  <Button type="submit" data-testid="create-item-submit" disabled={createItem.isPending}>
                    {createItem.isPending ? "Creating…" : "Create"}
                  </Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {itemsQuery.isError && (
        <p className="text-sm text-destructive">Failed to load warehouse items: {(itemsQuery.error as Error).message}</p>
      )}

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>SKU</TableHead>
            <TableHead>Name</TableHead>
            <TableHead>Category</TableHead>
            <TableHead>Location</TableHead>
            <TableHead className="text-right">Qty on hand</TableHead>
            <TableHead className="text-right">Unit Price</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {itemsQuery.isLoading && Array.from({ length: 3 }).map((_, i) => (
            <TableRow key={i}>
              {Array.from({ length: 6 }).map((__, j) => <TableCell key={j}><Skeleton className="h-4 w-full" /></TableCell>)}
            </TableRow>
          ))}
          {!itemsQuery.isLoading && itemsQuery.data?.length === 0 && (
            <TableRow><TableCell colSpan={6} className="text-center text-muted-foreground">No warehouse items yet.</TableCell></TableRow>
          )}
          {itemsQuery.data?.map((item) => {
            const lowStock = isLowStock(item.__PREFIX___availablequantity, item.__PREFIX___reorderpoint)
            return (
              <TableRow key={item.__PREFIX___warehouseitemid} data-testid="warehouse-item-row">
                <TableCell className="font-mono text-xs">{item.__PREFIX___sku}</TableCell>
                <TableCell>
                  <Link to={`/items/${item.__PREFIX___warehouseitemid}`} className="hover:underline font-medium">
                    {item.__PREFIX___name}
                  </Link>
                </TableCell>
                <TableCell><Badge variant="secondary">{item.__PREFIX___categoryname ?? "—"}</Badge></TableCell>
                <TableCell>{item.__PREFIX___locationidname ?? "—"}</TableCell>
                <TableCell className={`text-right ${lowStock ? "text-destructive font-semibold" : ""}`} data-testid="item-qty-on-hand">
                  {item.__PREFIX___availablequantity}
                </TableCell>
                <TableCell className="text-right">{formatCurrency(item.__PREFIX___unitprice)}</TableCell>
              </TableRow>
            )
          })}
        </TableBody>
      </Table>
    </div>
  )
}
