import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { __PASCAL___warehouseitemsService } from "@/generated/services/__PASCAL___warehouseitemsService";
import type { __PASCAL___warehouseitems } from "@/generated/models/__PASCAL___warehouseitemsModel";
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

  const { data: items, isLoading, error } = useQuery({
    queryKey: ["warehouseItems"],
    queryFn: async () => {
      const result = await __PASCAL___warehouseitemsService.getAll({
        select: [
          "__PREFIX___warehouseitemid",
          "__PREFIX___name",
          "__PREFIX___sku",
          "__PREFIX___availablequantity",
          "__PREFIX___category",
          "createdon",
          "statecode",
        ],
        orderBy: ["__PREFIX___name asc"],
      });
      return result.data ?? [];
    },
  });

  const createMutation = useMutation({
    mutationFn: async () => {
      return __PASCAL___warehouseitemsService.create({
        __PREFIX___name: name,
        __PREFIX___sku: sku,
        __PREFIX___availablequantity: quantity,
        __PREFIX___category: Number(category) as any,
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
              <TableHead>Status</TableHead>
              <TableHead>Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              Array.from({ length: 5 }).map((_, i) => (
                <TableRow key={i}>
                  {Array.from({ length: 6 }).map((_, j) => (
                    <TableCell key={j}>
                      <Skeleton className="h-4 w-full" />
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : items && items.length > 0 ? (
              items.map((item: __PASCAL___warehouseitems) => (
                <TableRow key={item.__PREFIX___warehouseitemid}>
                  <TableCell>
                    <Link
                      to={`/items/${item.__PREFIX___warehouseitemid}`}
                      className="font-medium text-primary hover:underline"
                    >
                      {item.__PREFIX___name}
                    </Link>
                  </TableCell>
                  <TableCell className="font-mono text-muted-foreground">
                    {item.__PREFIX___sku}
                  </TableCell>
                  <TableCell className="text-right font-mono">
                    {item.__PREFIX___availablequantity}
                  </TableCell>
                  <TableCell>
                    <Badge variant="secondary">
                      {categoryLabels[
                        item.__PREFIX___category as keyof typeof categoryLabels
                      ] ?? item.__PREFIX___category}
                    </Badge>
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
                <TableCell colSpan={6} className="text-center py-8 text-muted-foreground">
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
