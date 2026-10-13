import type { IOptionSetProperty } from "@talxis/base-controls";
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

// The same choices as base-controls option metadata (OptionSet control options, grid columns)
export const categoryOptionMetadata = categoryOptions.map((opt) => ({ Value: opt.value, Label: opt.label, Color: "" }));
export const transactionTypeOptionMetadata = transactionTypeOptions.map((opt) => ({ Value: opt.value, Label: opt.label, Color: "" }));

// statecode as a grid option set column: Active/Inactive with the same colors on every page
export const statusOptions = [
  { Value: 0, Label: "Active", Color: "#107C10" },
  { Value: 1, Label: "Inactive", Color: "#C50F1F" },
];

// Value parameter for a base-controls OptionSet field
export function optionSetProperty(
  raw: number | null,
  options: ComponentFramework.PropertyHelper.OptionMetadata[]
): IOptionSetProperty {
  return { raw, attributes: { Options: options } };
}
