import { useState } from "react"
import { Link } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import { Plus } from "lucide-react"
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
import { __PREFIX_PASCAL___warehousetransactionsService } from "@/generated/services/__PREFIX_PASCAL___warehousetransactionsService"
import type { __PREFIX_PASCAL___warehousetransactions__PREFIX___transactiontype } from "@/generated/models/__PREFIX_PASCAL___warehousetransactionsModel"
import { TRANSACTION_TYPE_OUTBOUND, transactionTypeOptions } from "@/utils/optionSets"

const emptyForm = { itemId: "", type: "", quantity: "1", referenceNumber: "" }

export default function TransactionsPage() {
  const queryClient = useQueryClient()
  const [open, setOpen] = useState(false)
  const [form, setForm] = useState(emptyForm)

  const transactionsQuery = useQuery({
    queryKey: ["allTransactions"],
    queryFn: async () => {
      const result = await __PREFIX_PASCAL___warehousetransactionsService.getAll({ orderBy: ["__PREFIX___transactiondate desc"] })
      if (!result.success) throw new Error(result.error?.message ?? "Failed to load transactions")
      return result.data
    },
  })

  const itemsQuery = useQuery({
    queryKey: ["warehouseItems"],
    queryFn: async () => {
      const result = await __PREFIX_PASCAL___warehouseitemsService.getAll({ orderBy: ["__PREFIX___name asc"] })
      if (!result.success) throw new Error(result.error?.message ?? "Failed to load warehouse items")
      return result.data
    },
  })

  const createTransaction = useMutation({
    mutationFn: async () => {
      const selectedItem = itemsQuery.data?.find((item) => item.__PREFIX___warehouseitemid === form.itemId)
      const typeLabel = transactionTypeOptions.find((option) => String(option.value) === form.type)?.label ?? "Transaction"
      const result = await __PREFIX_PASCAL___warehousetransactionsService.create({
        __PREFIX___name: `${typeLabel} - ${selectedItem?.__PREFIX___name ?? form.itemId} - ${new Date().toISOString()}`,
        "__PREFIX___itemid@odata.bind": `/__PREFIX___warehouseitems(${form.itemId})`,
        __PREFIX___quantity: Number(form.quantity),
        __PREFIX___transactiontype: Number(form.type) as __PREFIX_PASCAL___warehousetransactions__PREFIX___transactiontype,
        __PREFIX___transactiondate: new Date().toISOString(),
        __PREFIX___referencenumber: form.referenceNumber || undefined,
        // ownerid/owneridtype/statecode are required on Base (true for reads) but Dataverse
        // defaults all three on create. quantity is typed as string on Base too, but Dataverse's
        // Web API expects a real JSON number for a Whole Number field — the cast (through
        // unknown, since we're deliberately overriding both mismatches) still catches real typos
        // in the fields we do pass.
      } as unknown as Parameters<typeof __PREFIX_PASCAL___warehousetransactionsService.create>[0])
      if (!result.success) throw new Error(result.error?.message ?? "Failed to create transaction")
      return result.data
    },
    onSuccess: () => {
      toast.success("Transaction created")
      queryClient.invalidateQueries({ queryKey: ["allTransactions"] })
      setForm(emptyForm)
      setOpen(false)
    },
    onError: (error: Error) => toast.error(error.message),
  })

  return (
    <div className="py-8 space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Transactions</h1>
        <Dialog open={open} onOpenChange={(next) => { setOpen(next); if (!next) setForm(emptyForm) }}>
          <DialogTrigger asChild>
            <Button data-testid="new-transaction-button"><Plus className="h-4 w-4 mr-2" />New Transaction</Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader><DialogTitle>New Transaction</DialogTitle></DialogHeader>
            <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); createTransaction.mutate() }}>
              <div className="space-y-2">
                <Label htmlFor="tx-item">Item</Label>
                <Select value={form.itemId} onValueChange={(value) => setForm({ ...form, itemId: value })}>
                  <SelectTrigger id="tx-item"><SelectValue placeholder="Select an item" /></SelectTrigger>
                  <SelectContent>
                    {itemsQuery.data?.map((item) => (
                      <SelectItem key={item.__PREFIX___warehouseitemid} value={item.__PREFIX___warehouseitemid}>
                        {item.__PREFIX___name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="tx-type">Type</Label>
                <Select value={form.type} onValueChange={(value) => setForm({ ...form, type: value })}>
                  <SelectTrigger id="tx-type"><SelectValue placeholder="Select a type" /></SelectTrigger>
                  <SelectContent>
                    {transactionTypeOptions.map((option) => (
                      <SelectItem key={option.value} value={String(option.value)}>{option.label}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="tx-quantity">Quantity</Label>
                <Input
                  id="tx-quantity" type="number" min="1" required
                  value={form.quantity} onChange={(e) => setForm({ ...form, quantity: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="tx-reference">Reference Number</Label>
                <Input
                  id="tx-reference" value={form.referenceNumber}
                  onChange={(e) => setForm({ ...form, referenceNumber: e.target.value })}
                />
              </div>
              <DialogFooter>
                <Button
                  type="submit" data-testid="create-transaction-submit"
                  disabled={createTransaction.isPending || !form.itemId || !form.type}
                >
                  {createTransaction.isPending ? "Creating…" : "Create"}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {transactionsQuery.isError && (
        <p className="text-sm text-destructive">Failed to load transactions: {(transactionsQuery.error as Error).message}</p>
      )}

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Item</TableHead>
            <TableHead>Type</TableHead>
            <TableHead className="text-right">Quantity</TableHead>
            <TableHead>Date</TableHead>
            <TableHead>Reference</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {transactionsQuery.isLoading && Array.from({ length: 3 }).map((_, i) => (
            <TableRow key={i}>
              {Array.from({ length: 5 }).map((__, j) => <TableCell key={j}><Skeleton className="h-4 w-full" /></TableCell>)}
            </TableRow>
          ))}
          {!transactionsQuery.isLoading && transactionsQuery.data?.length === 0 && (
            <TableRow><TableCell colSpan={5} className="text-center text-muted-foreground">No transactions yet.</TableCell></TableRow>
          )}
          {transactionsQuery.data?.map((transaction) => (
            <TableRow key={transaction.__PREFIX___warehousetransactionid}>
              <TableCell>
                <Link to={`/items/${transaction.___PREFIX___itemid_value}`} className="hover:underline">
                  {transaction.__PREFIX___itemidname ?? "—"}
                </Link>
              </TableCell>
              <TableCell>
                <Badge variant={transaction.__PREFIX___transactiontype === TRANSACTION_TYPE_OUTBOUND ? "destructive" : "default"}>
                  {transaction.__PREFIX___transactiontypename}
                </Badge>
              </TableCell>
              <TableCell className="text-right">{transaction.__PREFIX___quantity}</TableCell>
              <TableCell>{new Date(transaction.__PREFIX___transactiondate).toLocaleString()}</TableCell>
              <TableCell>{transaction.__PREFIX___referencenumber ?? "—"}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}
