import type { IOptionSetProperty } from "@talxis/base-controls";
import { __PASCAL___warehouseitems__PREFIX___category } from "@/generated/models/__PASCAL___warehouseitemsModel";
import { __PASCAL___warehousetransactions__PREFIX___transactiontype } from "@/generated/models/__PASCAL___warehousetransactionsModel";

export const categoryLabels = __PASCAL___warehouseitems__PREFIX___category;

// Option set choices as base-controls option metadata (OptionSet control options, grid columns)
const toOptionMetadata = (labels: Record<number, string>) =>
  Object.entries(labels).map(([value, label]) => ({ Value: Number(value), Label: label, Color: "" }));

export const categoryOptionMetadata = toOptionMetadata(categoryLabels);
export const transactionTypeOptionMetadata = toOptionMetadata(__PASCAL___warehousetransactions__PREFIX___transactiontype);

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
