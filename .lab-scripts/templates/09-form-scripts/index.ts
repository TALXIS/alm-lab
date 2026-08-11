export class TransactionForm {
    /**
     * OnLoad handler for the Warehouse Transaction main form.
     * Sets default transaction date to today if empty.
     */
    public static onLoad(executionContext: Xrm.Events.EventContext): void {
        const formContext = executionContext.getFormContext();

        // Default transaction date to today
        const dateAttr = formContext.getAttribute("__PREFIX___transactiondate");
        if (dateAttr && !dateAttr.getValue()) {
            dateAttr.setValue(new Date());
        }
    }

    /**
     * OnChange handler for the quantity field.
     * Recalculates total value based on quantity x item unit price.
     */
    public static async onQuantityChange(executionContext: Xrm.Events.EventContext): Promise<void> {
        const formContext = executionContext.getFormContext();

        const quantity = (formContext.getAttribute("__PREFIX___quantity") as Xrm.Attributes.NumberAttribute)?.getValue();
        const itemAttr = formContext.getAttribute("__PREFIX___itemid") as Xrm.Attributes.LookupAttribute;
        const itemVal = itemAttr?.getValue() as Xrm.LookupValue[] | null;

        if (quantity && itemVal && itemVal.length) {
            try {
                const item = await Xrm.WebApi.retrieveRecord(
                    "__PREFIX___warehouseitem",
                    itemVal[0].id.replace(/[{}]/g, ""),
                    "?\$select=__PREFIX___unitprice"
                );
                const unitPrice = item["__PREFIX___unitprice"] as number;
                if (unitPrice) {
                    const totalValue = quantity * unitPrice;
                    (formContext.getAttribute("__PREFIX___totalvalue") as Xrm.Attributes.NumberAttribute)?.setValue(totalValue);
                }
            } catch {
                // Item not found or no price — leave total value unchanged
            }
        }
    }
}

export class RibbonActions {
    /**
     * Check Stock Levels — opens an alert showing the current stock for the selected item.
     */
    public static async checkStockLevels(formContext: Xrm.FormContext): Promise<void> {
        const name = (formContext.getAttribute("__PREFIX___name") as Xrm.Attributes.StringAttribute)?.getValue() ?? "Unknown";
        const qty = (formContext.getAttribute("__PREFIX___availablequantity") as Xrm.Attributes.NumberAttribute)?.getValue() ?? 0;
        const reorder = (formContext.getAttribute("__PREFIX___reorderpoint") as Xrm.Attributes.NumberAttribute)?.getValue() ?? 0;

        let message = "Stock level for " + name + ": " + qty + " units.";
        if (qty <= reorder) {
            message += "\n⚠ Below reorder point (" + reorder + "). Consider restocking.";
        } else {
            message += "\n✓ Stock is above reorder point (" + reorder + ").";
        }

        await Xrm.Navigation.openAlertDialog({ text: message, title: "Stock Check" });
    }
}