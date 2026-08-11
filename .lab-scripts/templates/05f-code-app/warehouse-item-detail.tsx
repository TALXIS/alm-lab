import { useState } from "react"
import { Link, useParams } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import { ArrowLeft, ArrowDownToLine, ArrowUpFromLine } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Skeleton } from "@/components/ui/skeleton"
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table"
import {
  Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle,
} from "@/components/ui/dialog"
import { __PREFIX_PASCAL___warehouseitemsService } from "@/generated/services/__PREFIX_PASCAL___warehouseitemsService"
import { __PREFIX_PASCAL___warehousetransactionsService } from "@/generated/services/__PREFIX_PASCAL___warehousetransactionsService"
import type { __PREFIX_PASCAL___warehousetransactions__PREFIX___transactiontype } from "@/generated/models/__PREFIX_PASCAL___warehousetransactionsModel"
import {
  TRANSACTION_TYPE_INBOUND, TRANSACTION_TYPE_OUTBOUND, isLowStock,
} from "@/utils/optionSets"

export default function WarehouseItemDetailPage() {
  const { id } = useParams<{ id: string }>()
  const queryClient = useQueryClient()
  const [dialogType, setDialogType] = useState<number | null>(null)
  const [quantity, setQuantity] = useState("1")
  const [referenceNumber, setReferenceNumber] = useState("")

  const itemQuery = useQuery({
    queryKey: ["warehouseItem", id],
    queryFn: async () => {
      const result = await __PREFIX_PASCAL___warehouseitemsService.get(id!)
      if (!result.success) throw new Error(result.error?.message ?? "Failed to load warehouse item")
      return result.data
    },
    enabled: !!id,
  })

  const transactionsQuery = useQuery({
    queryKey: ["itemTransactions", id],
    queryFn: async () => {
      const result = await __PREFIX_PASCAL___warehousetransactionsService.getAll({
        filter: `___PREFIX___itemid_value eq ${id}`,
        orderBy: ["__PREFIX___transactiondate desc"],
      })
      if (!result.success) throw new Error(result.error?.message ?? "Failed to load transactions")
      return result.data
    },
    enabled: !!id,
  })

  const closeDialog = () => { setDialogType(null); setQuantity("1"); setReferenceNumber("") }

  const createTransaction = useMutation({
    mutationFn: async () => {
      const actionLabel = dialogType === TRANSACTION_TYPE_OUTBOUND ? "Pick" : "Restock"
      const result = await __PREFIX_PASCAL___warehousetransactionsService.create({
        __PREFIX___name: `${actionLabel} - ${item?.__PREFIX___name ?? id} - ${new Date().toISOString()}`,
        "__PREFIX___itemid@odata.bind": `/__PREFIX___warehouseitems(${id})`,
        __PREFIX___quantity: String(quantity),
        __PREFIX___transactiontype: dialogType! as __PREFIX_PASCAL___warehousetransactions__PREFIX___transactiontype,
        __PREFIX___transactiondate: new Date().toISOString(),
        __PREFIX___referencenumber: referenceNumber || undefined,
        // ownerid/owneridtype/statecode are required on Base (true for reads) but Dataverse
        // defaults all three on create — the cast suppresses just that mismatch.
      } as Parameters<typeof __PREFIX_PASCAL___warehousetransactionsService.create>[0])
      if (!result.success) throw new Error(result.error?.message ?? "Failed to create transaction")
      return result.data
    },
    onSuccess: () => {
      toast.success(dialogType === TRANSACTION_TYPE_OUTBOUND ? "Picked" : "Restocked")
      queryClient.invalidateQueries({ queryKey: ["warehouseItem", id] })
      queryClient.invalidateQueries({ queryKey: ["itemTransactions", id] })
      closeDialog()
    },
    onError: (error: Error) => toast.error(error.message),
  })

  const item = itemQuery.data
  const available = Number(item?.__PREFIX___availablequantity ?? 0)
  const requestedQty = Number(quantity)
  const exceedsStock = dialogType === TRANSACTION_TYPE_OUTBOUND && requestedQty > available

  return (
    <div className="py-8 space-y-6">
      <Link to="/" className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="h-4 w-4 mr-1" />Back to items
      </Link>

      {itemQuery.isLoading && <Skeleton className="h-8 w-64" />}
      {itemQuery.isError && (
        <p className="text-sm text-destructive">Failed to load item: {(itemQuery.error as Error).message}</p>
      )}

      {item && (
        <>
          <div className="flex items-center justify-between">
            <h1 className="text-2xl font-semibold">{item.__PREFIX___name}</h1>
            <div className="flex items-center gap-2">
              <Button variant="outline" data-testid="restock-button" onClick={() => setDialogType(TRANSACTION_TYPE_INBOUND)}>
                <ArrowDownToLine className="h-4 w-4 mr-2" />Restock
              </Button>
              <Button data-testid="pick-button" onClick={() => setDialogType(TRANSACTION_TYPE_OUTBOUND)}>
                <ArrowUpFromLine className="h-4 w-4 mr-2" />Pick
              </Button>
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <Card>
              <CardHeader className="pb-2"><CardTitle className="text-sm text-muted-foreground">Qty on hand</CardTitle></CardHeader>
              <CardContent>
                <p
                  className={`text-3xl font-semibold ${isLowStock(item.__PREFIX___availablequantity, item.__PREFIX___reorderpoint) ? "text-destructive" : ""}`}
                  data-testid="item-detail-qty"
                >
                  {item.__PREFIX___availablequantity}
                </p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2"><CardTitle className="text-sm text-muted-foreground">Category</CardTitle></CardHeader>
              <CardContent><Badge variant="secondary">{item.__PREFIX___categoryname ?? "—"}</Badge></CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2"><CardTitle className="text-sm text-muted-foreground">Location</CardTitle></CardHeader>
              <CardContent><p className="text-lg">{item.__PREFIX___locationidname ?? "—"}</p></CardContent>
            </Card>
            <Card>
              <CardHeader className="pb-2"><CardTitle className="text-sm text-muted-foreground">Reorder Point</CardTitle></CardHeader>
              <CardContent><p className="text-lg">{item.__PREFIX___reorderpoint ?? "—"}</p></CardContent>
            </Card>
          </div>

          <div>
            <h2 className="text-lg font-medium mb-3">Transaction history</h2>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Type</TableHead>
                  <TableHead className="text-right">Quantity</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead>Reference</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {transactionsQuery.isLoading && Array.from({ length: 2 }).map((_, i) => (
                  <TableRow key={i}>
                    {Array.from({ length: 4 }).map((__, j) => <TableCell key={j}><Skeleton className="h-4 w-full" /></TableCell>)}
                  </TableRow>
                ))}
                {!transactionsQuery.isLoading && transactionsQuery.data?.length === 0 && (
                  <TableRow><TableCell colSpan={4} className="text-center text-muted-foreground">No transactions yet.</TableCell></TableRow>
                )}
                {transactionsQuery.data?.map((transaction) => (
                  <TableRow key={transaction.__PREFIX___warehousetransactionid}>
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
        </>
      )}

      <Dialog open={dialogType !== null} onOpenChange={(next) => { if (!next) closeDialog() }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{dialogType === TRANSACTION_TYPE_OUTBOUND ? "Pick" : "Restock"} — {item?.__PREFIX___name}</DialogTitle>
          </DialogHeader>
          <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); createTransaction.mutate() }}>
            <div className="space-y-2">
              <Label htmlFor="tx-quantity">Quantity</Label>
              <Input
                id="tx-quantity" type="number" min="1" required
                value={quantity} onChange={(e) => setQuantity(e.target.value)}
              />
              {exceedsStock && (
                <p className="text-sm text-destructive" data-testid="stock-warning">
                  Only {available} available — this will likely be rejected by the server.
                </p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="tx-reference">Reference Number</Label>
              <Input id="tx-reference" value={referenceNumber} onChange={(e) => setReferenceNumber(e.target.value)} />
            </div>
            <DialogFooter>
              <Button type="submit" data-testid="submit-transaction" disabled={createTransaction.isPending}>
                {createTransaction.isPending ? "Submitting…" : "Confirm"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  )
}
