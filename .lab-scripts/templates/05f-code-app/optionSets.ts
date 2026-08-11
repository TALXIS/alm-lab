import { __PASCAL___warehouseitems__PREFIX___category } from "@/generated/models/__PASCAL___warehouseitemsModel";
import { __PASCAL___warehousetransactions__PREFIX___transactiontype } from "@/generated/models/__PASCAL___warehousetransactionsModel";

export const categoryLabels = __PASCAL___warehouseitems__PREFIX___category;
export const transactionTypeLabels = __PASCAL___warehousetransactions__PREFIX___transactiontype;

export const categoryOptions = Object.entries(categoryLabels).map(
  ([value, label]) => ({ value: Number(value), label })
);

export const transactionTypeOptions = Object.entries(transactionTypeLabels).map(
  ([value, label]) => ({ value: Number(value), label })
);

// Matches the low-stock rule already used by the model-driven app's grid
// (Scripts.UI/src/GridCustomizer.ts) so both UI styles agree on what "low stock" means.
export const LOW_STOCK_FALLBACK = 10;

export function isLowStock(availableQuantity: unknown, reorderPoint: unknown): boolean {
  const quantity = Number(availableQuantity);
  const reorder = reorderPoint === null || reorderPoint === undefined || reorderPoint === ""
    ? LOW_STOCK_FALLBACK
    : Number(reorderPoint);
  return quantity <= reorder;
}
