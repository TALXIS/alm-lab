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
