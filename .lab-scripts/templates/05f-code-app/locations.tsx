import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { __PASCAL___warehouselocationsService } from "@/generated/services/__PASCAL___warehouselocationsService";
import { __PASCAL___warehouseitemsService } from "@/generated/services/__PASCAL___warehouseitemsService";
import type { __PASCAL___warehouselocations } from "@/generated/models/__PASCAL___warehouselocationsModel";
import type { __PASCAL___warehouseitems } from "@/generated/models/__PASCAL___warehouseitemsModel";
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
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { toast } from "sonner";
import { MapPin, Plus, RefreshCw } from "lucide-react";

export default function LocationsPage() {
  const queryClient = useQueryClient();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [name, setName] = useState("");
  const [address, setAddress] = useState("");
  const [capacity, setCapacity] = useState("");

  const { data: locations, isLoading, error } = useQuery({
    queryKey: ["warehouseLocationsList"],
    queryFn: async () => {
      const result = await __PASCAL___warehouselocationsService.getAll({
        select: [
          "__PREFIX___warehouselocationid",
          "__PREFIX___name",
          "__PREFIX___address",
          "__PREFIX___capacity",
          "__PREFIX___isactive",
          "statecode",
        ],
        orderBy: ["__PREFIX___name asc"],
      });
      return result.data ?? [];
    },
  });

  const { data: items } = useQuery({
    queryKey: ["itemsByLocation"],
    queryFn: async () => {
      const result = await __PASCAL___warehouseitemsService.getAll({
        select: ["__PREFIX___warehouseitemid", "___PREFIX___locationid_value"],
      });
      return result.data ?? [];
    },
  });

  const itemCounts = new Map<string, number>();
  (items ?? []).forEach((item: __PASCAL___warehouseitems) => {
    const locId = item.___PREFIX___locationid_value;
    if (locId) itemCounts.set(locId, (itemCounts.get(locId) ?? 0) + 1);
  });

  const createMutation = useMutation({
    mutationFn: async () => {
      return __PASCAL___warehouselocationsService.create({
        __PREFIX___name: name,
        __PREFIX___address: address,
        __PREFIX___capacity: capacity,
        __PREFIX___isactive: true,
      } as any);
    },
    onSuccess: async () => {
      await queryClient.refetchQueries({ queryKey: ["warehouseLocationsList"] });
      toast.success("Location created successfully");
      resetForm();
    },
    onError: (err) => {
      toast.error("Failed to create location: " + String(err));
    },
  });

  const resetForm = () => {
    setDialogOpen(false);
    setName("");
    setAddress("");
    setCapacity("");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name) {
      toast.error("Please fill all required fields");
      return;
    }
    createMutation.mutate();
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <MapPin className="h-8 w-8 text-primary" />
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">
              Locations
            </h1>
            <p className="text-sm text-muted-foreground">
              Warehouse locations and their stock
            </p>
          </div>
        </div>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="icon"
            onClick={() =>
              queryClient.refetchQueries({ queryKey: ["warehouseLocationsList"] })
            }
          >
            <RefreshCw className="h-4 w-4" />
          </Button>
          <Button onClick={() => setDialogOpen(true)}>
            <Plus className="h-4 w-4 mr-2" />
            New Location
          </Button>
        </div>
      </div>

      {error && (
        <div className="rounded-md bg-destructive/10 p-4 text-destructive text-sm">
          Failed to load locations: {String(error)}
        </div>
      )}

      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Address</TableHead>
              <TableHead className="text-right">Capacity</TableHead>
              <TableHead className="text-right">Items</TableHead>
              <TableHead>Active</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              Array.from({ length: 5 }).map((_, i) => (
                <TableRow key={i}>
                  {Array.from({ length: 5 }).map((_, j) => (
                    <TableCell key={j}>
                      <Skeleton className="h-4 w-full" />
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : locations && locations.length > 0 ? (
              locations.map((loc: __PASCAL___warehouselocations) => (
                <TableRow key={loc.__PREFIX___warehouselocationid}>
                  <TableCell className="font-medium">
                    {loc.__PREFIX___name}
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    {loc.__PREFIX___address || "-"}
                  </TableCell>
                  <TableCell className="text-right font-mono">
                    {loc.__PREFIX___capacity ?? "-"}
                  </TableCell>
                  <TableCell className="text-right font-mono">
                    {itemCounts.get(loc.__PREFIX___warehouselocationid) ?? 0}
                  </TableCell>
                  <TableCell>
                    <Badge variant={loc.__PREFIX___isactive ? "default" : "destructive"}>
                      {loc.__PREFIX___isactive ? "Active" : "Inactive"}
                    </Badge>
                  </TableCell>
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell
                  colSpan={5}
                  className="text-center py-8 text-muted-foreground"
                >
                  No locations found
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Create New Location</DialogTitle>
          </DialogHeader>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="locName">Name *</Label>
              <Input
                id="locName"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Enter location name"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="locAddress">Address</Label>
              <Input
                id="locAddress"
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                placeholder="Enter address"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="locCapacity">Capacity</Label>
              <Input
                id="locCapacity"
                type="number"
                min="0"
                value={capacity}
                onChange={(e) => setCapacity(e.target.value)}
                placeholder="0"
              />
            </div>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={resetForm}>
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
