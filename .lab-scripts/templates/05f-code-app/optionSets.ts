import { __PREFIX_PASCAL___warehouseitems__PREFIX___category } from "@/generated/models/__PREFIX_PASCAL___warehouseitemsModel"
import { __PREFIX_PASCAL___warehousetransactions__PREFIX___transactiontype } from "@/generated/models/__PREFIX_PASCAL___warehousetransactionsModel"

function optionValueByLabel(options: Record<number, string>, label: string): number {
  const entry = Object.entries(options).find(([, optionLabel]) => optionLabel === label)
  if (!entry) throw new Error(`Option "${label}" not found in ${JSON.stringify(options)}`)
  return Number(entry[0])
}

export const categoryOptions = Object.entries(__PREFIX_PASCAL___warehouseitems__PREFIX___category).map(
  ([value, label]) => ({ value: Number(value), label })
)

export const transactionTypeOptions = Object.entries(__PREFIX_PASCAL___warehousetransactions__PREFIX___transactiontype).map(
  ([value, label]) => ({ value: Number(value), label })
)

export const TRANSACTION_TYPE_INBOUND = optionValueByLabel(__PREFIX_PASCAL___warehousetransactions__PREFIX___transactiontype, "Inbound")
export const TRANSACTION_TYPE_OUTBOUND = optionValueByLabel(__PREFIX_PASCAL___warehousetransactions__PREFIX___transactiontype, "Outbound")

// Matches the low-stock rule already used by the model-driven app's grid
// (Scripts.UI/src/GridCustomizer.ts) so both UI styles agree on what "low stock" means.
export const LOW_STOCK_FALLBACK = 10

export function isLowStock(availableQuantity: unknown, reorderPoint: unknown): boolean {
  const quantity = Number(availableQuantity)
  const reorder = reorderPoint === null || reorderPoint === undefined || reorderPoint === ""
    ? LOW_STOCK_FALLBACK
    : Number(reorderPoint)
  return quantity <= reorder
}

export function formatCurrency(value: unknown): string {
  if (value === null || value === undefined || value === "") return "—"
  const amount = Number(value)
  if (Number.isNaN(amount)) return "—"
  return amount.toLocaleString(undefined, { style: "currency", currency: "USD" })
}
