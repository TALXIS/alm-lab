import { useState } from "react";
import { useParams, Link } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Almlab_warehouseitemsService } from "@/generated/services/Almlab_warehouseitemsService";
import { Almlab_warehousetransactionsService } from "@/generated/services/Almlab_warehousetransactionsService";
import { Almlab_warehouselocationsService } from "@/generated/services/Almlab_warehouselocationsService";
import type { Almlab_warehousetransactions } from "@/generated/models/Almlab_warehousetransactionsModel";
import type { Almlab_warehouselocations } from "@/generated/models/Almlab_warehouselocationsModel";
import {
  categoryLabels,
  transactionTypeLabels,
  transactionTypeOptions,
} from "@/utils/optionSets";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
import { ArrowLeft, Plus, Package, ArrowRightLeft, MapPin } from "lucide-react";

export default function WarehouseItemDetailPage() {
  const { id } = useParams<{ id: string }>();
  const queryClient = useQueryClient();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [txName, setTxName] = useState("");
  const [txQuantity, setTxQuantity] = useState("");
  const [txType, setTxType] = useState("");

  const { data: item, isLoading: itemLoading } = useQuery({
    queryKey: ["warehouseItem", id],
    queryFn: async () => {
      const result = await Almlab_warehouseitemsService.get(id!);
      return result.data;
    },
    enabled: !!id,
  });

  const { data: transactions, isLoading: txLoading } = useQuery({
    queryKey: ["itemTransactions", id],
    queryFn: async () => {
      const result = await Almlab_warehousetransactionsService.getAll({
        select: [
          "almlab_warehousetransactionid",
          "almlab_name",
          "almlab_quantity",
          "almlab_transactiontype",
          "almlab_transactiondate",
        ],
        filter: `_almlab_itemid_value eq '${id}'`,
        orderBy: ["almlab_transactiondate desc"],
      });
      return result.data ?? [];
    },
    enabled: !!id,
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

  const createTxMutation = useMutation({
    mutationFn: async () => {
      return Almlab_warehousetransactionsService.create({
        almlab_name: txName,
        almlab_quantity: txQuantity,
        almlab_transactiontype: Number(txType) as any,
        almlab_transactiondate: new Date().toISOString(),
        "almlab_itemid@odata.bind": `/almlab_warehouseitems(${id})`,
      } as any);
    },
    onSuccess: async () => {
      await queryClient.refetchQueries({ queryKey: ["itemTransactions", id] });
      await queryClient.refetchQueries({ queryKey: ["warehouseItem", id] });
      toast.success("Transaction created");
      resetForm();
    },
    onError: (err) => {
      toast.error("Failed to create transaction: " + String(err));
    },
  });

  const resetForm = () => {
    setDialogOpen(false);
    setTxName("");
    setTxQuantity("");
    setTxType("");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!txName || !txQuantity || !txType) {
      toast.error("Please fill all required fields");
      return;
    }
    createTxMutation.mutate();
  };

  if (itemLoading) {
    return (
      <div className="p-6 space-y-6">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-32 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }

  if (!item) {
    return (
      <div className="p-6">
        <p className="text-muted-foreground">Item not found.</p>
        <Link to="/">
          <Button variant="link" className="mt-2">
            <ArrowLeft className="h-4 w-4 mr-2" /> Back to items
          </Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center gap-4">
        <Link to="/">
          <Button variant="ghost" size="icon">
            <ArrowLeft className="h-4 w-4" />
          </Button>
        </Link>
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">
            {item.almlab_name}
          </h1>
          <p className="text-sm text-muted-foreground font-mono">
            {item.almlab_sku}
          </p>
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Available Quantity
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold" data-testid="item-detail-qty">
              {item.almlab_availablequantity}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Category
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex items-center gap-2">
              <Package className="h-5 w-5 text-muted-foreground" />
              <span className="text-lg font-medium">
                {categoryLabels[
                  item.almlab_category as keyof typeof categoryLabels
                ] ?? item.almlab_category}
              </span>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Location
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex items-center gap-2">
              <MapPin className="h-5 w-5 text-muted-foreground" />
              <span className="text-lg font-medium">
                {locationNames.get(item._almlab_locationid_value ?? "") ?? "-"}
              </span>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Status
            </CardTitle>
          </CardHeader>
          <CardContent>
            <Badge variant={item.statecode === 0 ? "default" : "destructive"}>
              {item.statecode === 0 ? "Active" : "Inactive"}
            </Badge>
          </CardContent>
        </Card>
      </div>

      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <ArrowRightLeft className="h-5 w-5 text-muted-foreground" />
            <h2 className="text-lg font-semibold">Transactions</h2>
          </div>
          <Button size="sm" data-testid="new-transaction-button" onClick={() => setDialogOpen(true)}>
            <Plus className="h-4 w-4 mr-2" />
            New Transaction
          </Button>
        </div>

        <div className="rounded-md border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Name</TableHead>
                <TableHead className="text-right">Quantity</TableHead>
                <TableHead>Type</TableHead>
                <TableHead>Date</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {txLoading ? (
                Array.from({ length: 3 }).map((_, i) => (
                  <TableRow key={i}>
                    {Array.from({ length: 4 }).map((_, j) => (
                      <TableCell key={j}>
                        <Skeleton className="h-4 w-full" />
                      </TableCell>
                    ))}
                  </TableRow>
                ))
              ) : transactions && transactions.length > 0 ? (
                transactions.map((tx: Almlab_warehousetransactions) => (
                  <TableRow key={tx.almlab_warehousetransactionid}>
                    <TableCell className="font-medium">
                      {tx.almlab_name}
                    </TableCell>
                    <TableCell className="text-right font-mono">
                      {tx.almlab_quantity}
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline">
                        {transactionTypeLabels[
                          tx.almlab_transactiontype as keyof typeof transactionTypeLabels
                        ] ?? tx.almlab_transactiontype}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {tx.almlab_transactiondate
                        ? new Date(tx.almlab_transactiondate).toLocaleDateString()
                        : "-"}
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell
                    colSpan={4}
                    className="text-center py-8 text-muted-foreground"
                  >
                    No transactions yet
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>
      </div>

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>New Transaction for {item.almlab_name}</DialogTitle>
          </DialogHeader>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="txName">Transaction Name *</Label>
              <Input
                id="txName"
                value={txName}
                onChange={(e) => setTxName(e.target.value)}
                placeholder="Enter transaction name"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="txQuantity">Quantity *</Label>
              <Input
                id="txQuantity"
                type="number"
                min="0"
                value={txQuantity}
                onChange={(e) => setTxQuantity(e.target.value)}
                placeholder="0"
              />
            </div>
            <div className="space-y-2">
              <Label>Transaction Type *</Label>
              <Select value={txType} onValueChange={setTxType}>
                <SelectTrigger data-testid="tx-type-trigger">
                  <SelectValue placeholder="Select transaction type" />
                </SelectTrigger>
                <SelectContent>
                  {transactionTypeOptions.map((opt) => (
                    <SelectItem key={opt.value} value={String(opt.value)}>
                      {opt.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={resetForm}>
                Cancel
              </Button>
              <Button type="submit" data-testid="submit-transaction" disabled={createTxMutation.isPending}>
                {createTxMutation.isPending ? "Creating..." : "Create"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}

