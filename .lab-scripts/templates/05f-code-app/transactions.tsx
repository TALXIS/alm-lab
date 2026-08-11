import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { __PASCAL___warehousetransactionsService } from "@/generated/services/__PASCAL___warehousetransactionsService";
import { __PASCAL___warehouseitemsService } from "@/generated/services/__PASCAL___warehouseitemsService";
import type { __PASCAL___warehousetransactions } from "@/generated/models/__PASCAL___warehousetransactionsModel";
import type { __PASCAL___warehouseitems } from "@/generated/models/__PASCAL___warehouseitemsModel";
import { transactionTypeLabels, transactionTypeOptions } from "@/utils/optionSets";
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
import { ArrowRightLeft, Plus, RefreshCw } from "lucide-react";

export default function TransactionsPage() {
  const queryClient = useQueryClient();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [txName, setTxName] = useState("");
  const [txQuantity, setTxQuantity] = useState("");
  const [txType, setTxType] = useState("");
  const [txItemId, setTxItemId] = useState("");

  const { data: transactions, isLoading, error } = useQuery({
    queryKey: ["allTransactions"],
    queryFn: async () => {
      const result = await __PASCAL___warehousetransactionsService.getAll({
        select: [
          "__PREFIX___warehousetransactionid",
          "__PREFIX___name",
          "__PREFIX___quantity",
          "__PREFIX___transactiontype",
          "__PREFIX___transactiondate",
          "statecode",
        ],
        orderBy: ["__PREFIX___transactiondate desc"],
      });
      return result.data ?? [];
    },
  });

  const { data: items } = useQuery({
    queryKey: ["warehouseItemsLookup"],
    queryFn: async () => {
      const result = await __PASCAL___warehouseitemsService.getAll({
        select: ["__PREFIX___warehouseitemid", "__PREFIX___name"],
        filter: "statecode eq 0",
        orderBy: ["__PREFIX___name asc"],
      });
      return result.data ?? [];
    },
  });

  const createMutation = useMutation({
    mutationFn: async () => {
      return __PASCAL___warehousetransactionsService.create({
        __PREFIX___name: txName,
        __PREFIX___quantity: txQuantity,
        __PREFIX___transactiontype: Number(txType) as any,
        __PREFIX___transactiondate: new Date().toISOString(),
        "__PREFIX___itemid@odata.bind": `/__PREFIX___warehouseitems(${txItemId})`,
      } as any);
    },
    onSuccess: async () => {
      await queryClient.refetchQueries({ queryKey: ["allTransactions"] });
      toast.success("Transaction created successfully");
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
    setTxItemId("");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!txName || !txQuantity || !txType || !txItemId) {
      toast.error("Please fill all required fields");
      return;
    }
    createMutation.mutate();
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <ArrowRightLeft className="h-8 w-8 text-primary" />
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">
              Transactions
            </h1>
            <p className="text-sm text-muted-foreground">
              All warehouse transactions
            </p>
          </div>
        </div>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="icon"
            onClick={() =>
              queryClient.refetchQueries({ queryKey: ["allTransactions"] })
            }
          >
            <RefreshCw className="h-4 w-4" />
          </Button>
          <Button onClick={() => setDialogOpen(true)}>
            <Plus className="h-4 w-4 mr-2" />
            New Transaction
          </Button>
        </div>
      </div>

      {error && (
        <div className="rounded-md bg-destructive/10 p-4 text-destructive text-sm">
          Failed to load transactions: {String(error)}
        </div>
      )}

      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead className="text-right">Quantity</TableHead>
              <TableHead>Type</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Date</TableHead>
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
            ) : transactions && transactions.length > 0 ? (
              transactions.map((tx: __PASCAL___warehousetransactions) => (
                <TableRow key={tx.__PREFIX___warehousetransactionid}>
                  <TableCell className="font-medium">{tx.__PREFIX___name}</TableCell>
                  <TableCell className="text-right font-mono">
                    {tx.__PREFIX___quantity}
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline">
                      {transactionTypeLabels[
                        tx.__PREFIX___transactiontype as keyof typeof transactionTypeLabels
                      ] ?? tx.__PREFIX___transactiontype}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <Badge
                      variant={tx.statecode === 0 ? "default" : "destructive"}
                    >
                      {tx.statecode === 0 ? "Active" : "Inactive"}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    {tx.__PREFIX___transactiondate
                      ? new Date(tx.__PREFIX___transactiondate).toLocaleDateString()
                      : "-"}
                  </TableCell>
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell
                  colSpan={5}
                  className="text-center py-8 text-muted-foreground"
                >
                  No transactions found
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Create New Transaction</DialogTitle>
          </DialogHeader>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="txName">Name *</Label>
              <Input
                id="txName"
                value={txName}
                onChange={(e) => setTxName(e.target.value)}
                placeholder="Enter transaction name"
              />
            </div>
            <div className="space-y-2">
              <Label>Warehouse Item *</Label>
              <Select value={txItemId} onValueChange={setTxItemId}>
                <SelectTrigger>
                  <SelectValue placeholder="Select item" />
                </SelectTrigger>
                <SelectContent>
                  {(items ?? []).map((item: __PASCAL___warehouseitems) => (
                    <SelectItem
                      key={item.__PREFIX___warehouseitemid}
                      value={item.__PREFIX___warehouseitemid}
                    >
                      {item.__PREFIX___name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
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
                <SelectTrigger>
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
