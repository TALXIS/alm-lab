import { Almlab_warehouseitemsalmlab_category } from "@/generated/models/Almlab_warehouseitemsModel";
import { Almlab_warehousetransactionsalmlab_transactiontype } from "@/generated/models/Almlab_warehousetransactionsModel";

export const categoryLabels = Almlab_warehouseitemsalmlab_category;
export const transactionTypeLabels = Almlab_warehousetransactionsalmlab_transactiontype;

export const categoryOptions = Object.entries(categoryLabels).map(
  ([value, label]) => ({ value: Number(value), label })
);

export const transactionTypeOptions = Object.entries(transactionTypeLabels).map(
  ([value, label]) => ({ value: Number(value), label })
);

