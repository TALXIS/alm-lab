import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { Almlab_warehouseitemsService } from "@/generated/services/Almlab_warehouseitemsService";
import { Almlab_warehouselocationsService } from "@/generated/services/Almlab_warehouselocationsService";
import type { Almlab_warehouseitems } from "@/generated/models/Almlab_warehouseitemsModel";
import type { Almlab_warehouselocations } from "@/generated/models/Almlab_warehouselocationsModel";
import { categoryLabels, categoryOptions } from "@/utils/optionSets";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { toast } from "sonner";
import { Package, Plus, RefreshCw } from "lucide-react";

export default function WarehouseItemsPage() {
  const queryClient = useQueryClient();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [name, setName] = useState("");
  const [sku, setSku] = useState("");
  const [quantity, setQuantity] = useState("");
  const [category, setCategory] = useState("");
  const [locationId, setLocationId] = useState("");

  const { data: items, isLoading, error } = useQuery({
    queryKey: ["warehouseItems"],
    queryFn: async () => {
      const result = await Almlab_warehouseitemsService.getAll({
        select: [
          "almlab_warehouseitemid",
          "almlab_name",
          "almlab_sku",
          "almlab_availablequantity",
          "almlab_category",
          "_almlab_locationid_value",
          "createdon",
          "statecode",
        ],
        orderBy: ["almlab_name asc"],
      });
      return result.data ?? [];
    },
  });

  const { data: locations } = useQuery({
    queryKey: ["warehouseLocations"],
    queryFn: async () => {
      const result = await Almlab_warehouselocationsService.getAll({
        select: ["almlab_warehouselocationid", "almlab_name"],
        orderBy: ["almlab_name asc"],
      });
      return result.data ?? [];
    },
  });

  const locationNames = new Map(
    (locations ?? []).map((loc: Almlab_warehouselocations) => [
      loc.almlab_warehouselocationid,
      loc.almlab_name,
    ])
  );

  const createMutation = useMutation({
    mutationFn: async () => {
      return Almlab_warehouseitemsService.create({
        almlab_name: name,
        almlab_sku: sku,
        almlab_availablequantity: quantity,
        almlab_category: Number(category) as any,
        ...(locationId
          ? { "almlab_locationid@odata.bind": `/almlab_warehouselocations(${locationId})` }
          : {}),
      } as any);
    },
    onSuccess: async () => {
      await queryClient.refetchQueries({ queryKey: ["warehouseItems"] });
      toast.success("Item created successfully");
      resetForm();
    },
    onError: (err) => {
      toast.error("Failed to create item: " + String(err));
    },
  });

  const resetForm = () => {
    setDialogOpen(false);
    setName("");
    setSku("");
    setQuantity("");
    setCategory("");
    setLocationId("");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !sku || !quantity || !category) {
      toast.error("Please fill all required fields");
      return;
    }
    createMutation.mutate();
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Package className="h-8 w-8 text-primary" />
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">
              Warehouse Items
            </h1>
            <p className="text-sm text-muted-foreground">
              Manage your warehouse inventory
            </p>
          </div>
        </div>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="icon"
            onClick={() =>
              queryClient.invalidateQueries({ queryKey: ["warehouseItems"] })
            }
          >
            <RefreshCw className="h-4 w-4" />
          </Button>
          <Button onClick={() => setDialogOpen(true)}>
            <Plus className="h-4 w-4 mr-2" />
            New Item
          </Button>
        </div>
      </div>

      {error && (
        <div className="rounded-md bg-destructive/10 p-4 text-destructive text-sm">
          Failed to load items: {String(error)}
        </div>
      )}

      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>SKU</TableHead>
              <TableHead className="text-right">Available Qty</TableHead>
              <TableHead>Category</TableHead>
              <TableHead>Location</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              Array.from({ length: 5 }).map((_, i) => (
                <TableRow key={i}>
                  {Array.from({ length: 7 }).map((_, j) => (
                    <TableCell key={j}>
                      <Skeleton className="h-4 w-full" />
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : items && items.length > 0 ? (
              items.map((item: Almlab_warehouseitems) => (
                <TableRow key={item.almlab_warehouseitemid} data-testid="warehouse-item-row">
                  <TableCell>
                    <Link
                      to={`/items/${item.almlab_warehouseitemid}`}
                      className="font-medium text-primary hover:underline"
                    >
                      {item.almlab_name}
                    </Link>
                  </TableCell>
                  <TableCell className="font-mono text-muted-foreground">
                    {item.almlab_sku}
                  </TableCell>
                  <TableCell className="text-right font-mono">
                    {item.almlab_availablequantity}
                  </TableCell>
                  <TableCell>
                    <Badge variant="secondary">
                      {categoryLabels[
                        item.almlab_category as keyof typeof categoryLabels
                      ] ?? item.almlab_category}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    {locationNames.get(item._almlab_locationid_value ?? "") ?? "-"}
                  </TableCell>
                  <TableCell>
                    <Badge
                      variant={
                        item.statecode === 0 ? "default" : "destructive"
                      }
                    >
                      {item.statecode === 0 ? "Active" : "Inactive"}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    {item.createdon
                      ? new Date(item.createdon).toLocaleDateString()
                      : "-"}
                  </TableCell>
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={7} className="text-center py-8 text-muted-foreground">
                  No warehouse items found
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Create New Item</DialogTitle>
          </DialogHeader>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="name">Name *</Label>
              <Input
                id="name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Enter item name"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="sku">SKU *</Label>
              <Input
                id="sku"
                value={sku}
                onChange={(e) => setSku(e.target.value)}
                placeholder="Enter SKU"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="quantity">Available Quantity *</Label>
              <Input
                id="quantity"
                type="number"
                min="0"
                value={quantity}
                onChange={(e) => setQuantity(e.target.value)}
                placeholder="0"
              />
            </div>
            <div className="space-y-2">
              <Label>Category *</Label>
              <Select value={category} onValueChange={setCategory}>
                <SelectTrigger>
                  <SelectValue placeholder="Select category" />
                </SelectTrigger>
                <SelectContent>
                  {categoryOptions.map((opt) => (
                    <SelectItem key={opt.value} value={String(opt.value)}>
                      {opt.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>Location</Label>
              <Select value={locationId} onValueChange={setLocationId}>
                <SelectTrigger>
                  <SelectValue placeholder="Select location (optional)" />
                </SelectTrigger>
                <SelectContent>
                  {(locations ?? []).map((loc: Almlab_warehouselocations) => (
                    <SelectItem
                      key={loc.almlab_warehouselocationid}
                      value={loc.almlab_warehouselocationid}
                    >
                      {loc.almlab_name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={resetForm}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={createMutation.isPending}>
                {createMutation.isPending ? "Creating..." : "Create"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}

