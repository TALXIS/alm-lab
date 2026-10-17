import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Almlab_warehouselocationsService } from "@/generated/services/Almlab_warehouselocationsService";
import { Almlab_warehouseitemsService } from "@/generated/services/Almlab_warehouseitemsService";
import type { Almlab_warehouselocations } from "@/generated/models/Almlab_warehouselocationsModel";
import type { Almlab_warehouseitems } from "@/generated/models/Almlab_warehouseitemsModel";
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
      const result = await Almlab_warehouselocationsService.getAll({
        select: [
          "almlab_warehouselocationid",
          "almlab_name",
          "almlab_address",
          "almlab_capacity",
          "almlab_isactive",
          "statecode",
        ],
        orderBy: ["almlab_name asc"],
      });
      return result.data ?? [];
    },
  });

  const { data: items } = useQuery({
    queryKey: ["itemsByLocation"],
    queryFn: async () => {
      const result = await Almlab_warehouseitemsService.getAll({
        select: ["almlab_warehouseitemid", "_almlab_locationid_value"],
      });
      return result.data ?? [];
    },
  });

  const itemCounts = new Map<string, number>();
  (items ?? []).forEach((item: Almlab_warehouseitems) => {
    const locId = item._almlab_locationid_value;
    if (locId) itemCounts.set(locId, (itemCounts.get(locId) ?? 0) + 1);
  });

  const createMutation = useMutation({
    mutationFn: async () => {
      return Almlab_warehouselocationsService.create({
        almlab_name: name,
        almlab_address: address,
        almlab_capacity: capacity,
        almlab_isactive: true,
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
              locations.map((loc: Almlab_warehouselocations) => (
                <TableRow key={loc.almlab_warehouselocationid}>
                  <TableCell className="font-medium">
                    {loc.almlab_name}
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    {loc.almlab_address || "-"}
                  </TableCell>
                  <TableCell className="text-right font-mono">
                    {loc.almlab_capacity ?? "-"}
                  </TableCell>
                  <TableCell className="text-right font-mono">
                    {itemCounts.get(loc.almlab_warehouselocationid) ?? 0}
                  </TableCell>
                  <TableCell>
                    <Badge variant={loc.almlab_isactive ? "default" : "destructive"}>
                      {loc.almlab_isactive ? "Active" : "Inactive"}
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

