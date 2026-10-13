import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { __PASCAL___warehouseitemsService } from "@/generated/services/__PASCAL___warehouseitemsService";
import { __PASCAL___warehouselocationsService } from "@/generated/services/__PASCAL___warehouselocationsService";
import type { __PASCAL___warehouseitems } from "@/generated/models/__PASCAL___warehouseitemsModel";
import type { __PASCAL___warehouselocations } from "@/generated/models/__PASCAL___warehouselocationsModel";
import { categoryOptionMetadata, statusOptions, optionSetProperty } from "@/utils/optionSets";
import {
  Button,
  Dialog,
  DialogActions,
  DialogBody,
  DialogContent,
  DialogSurface,
  DialogTitle,
  Field,
  MessageBar,
  MessageBarBody,
  Skeleton,
  SkeletonItem,
  makeStyles,
  tokens,
} from "@fluentui/react-components";
import { BoxRegular, AddRegular, ArrowClockwiseRegular } from "@fluentui/react-icons";
import { Decimal, OptionSet, TextField, usePcfContext } from "@talxis/base-controls";
import type { IColumn } from "@talxis/client-libraries";
import { PageHeader } from "@/components/PageHeader";
import { RecordGrid } from "@/components/RecordGrid";
import { RecordLookup } from "@/components/RecordLookup";
import { useToast } from "@/hooks/use-toast";

const useStyles = makeStyles({
  page: {
    padding: tokens.spacingHorizontalXXL,
    display: "flex",
    flexDirection: "column",
    gap: tokens.spacingVerticalXL,
  },
  form: {
    display: "flex",
    flexDirection: "column",
    gap: tokens.spacingVerticalM,
  },
});

const columns: IColumn[] = [
  { name: "__PREFIX___name", displayName: "Name", dataType: "SingleLine.Text", isPrimary: true, visualSizeFactor: 220 },
  { name: "__PREFIX___sku", displayName: "SKU", dataType: "SingleLine.Text", visualSizeFactor: 130 },
  { name: "__PREFIX___availablequantity", displayName: "Available Qty", dataType: "Whole.None", visualSizeFactor: 120 },
  { name: "__PREFIX___category", displayName: "Category", dataType: "OptionSet", visualSizeFactor: 140, metadata: { OptionSet: categoryOptionMetadata } as IColumn["metadata"] },
  { name: "location", displayName: "Location", dataType: "SingleLine.Text", visualSizeFactor: 150 },
  { name: "statecode", displayName: "Status", dataType: "OptionSet", visualSizeFactor: 110, metadata: { OptionSet: statusOptions } as IColumn["metadata"] },
  { name: "createdon", displayName: "Created", dataType: "DateAndTime.DateOnly", visualSizeFactor: 120 },
];

export default function WarehouseItemsPage() {
  const styles = useStyles();
  const toast = useToast();
  const context = usePcfContext();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [name, setName] = useState("");
  const [sku, setSku] = useState("");
  const [quantity, setQuantity] = useState<number | null>(null);
  const [category, setCategory] = useState<number | null>(null);
  const [locationId, setLocationId] = useState("");

  const { data: items, isLoading, error } = useQuery({
    queryKey: ["warehouseItems"],
    queryFn: async () => {
      const result = await __PASCAL___warehouseitemsService.getAll({
        select: [
          "__PREFIX___warehouseitemid",
          "__PREFIX___name",
          "__PREFIX___sku",
          "__PREFIX___availablequantity",
          "__PREFIX___category",
          "___PREFIX___locationid_value",
          "createdon",
          "statecode",
        ],
        orderBy: ["__PREFIX___name asc"],
      });
      return result.data ?? [];
    },
  });

  const { data: locations } = useQuery({
    queryKey: ["warehouseLocations"],
    queryFn: async () => {
      const result = await __PASCAL___warehouselocationsService.getAll({
        select: ["__PREFIX___warehouselocationid", "__PREFIX___name"],
        orderBy: ["__PREFIX___name asc"],
      });
      return result.data ?? [];
    },
  });

  const locationRecords = useMemo(
    () =>
      (locations ?? []).map((loc: __PASCAL___warehouselocations) => ({
        id: loc.__PREFIX___warehouselocationid,
        name: loc.__PREFIX___name ?? "",
      })),
    [locations]
  );

  // Grid rows: numbers for numeric/option set columns, and the location lookup resolved to its name
  const rows = useMemo(() => {
    if (!items) return undefined;
    const locationNames = new Map(locationRecords.map((loc) => [loc.id, loc.name]));
    return items.map((item: __PASCAL___warehouseitems) => ({
      ...item,
      __PREFIX___availablequantity: Number(item.__PREFIX___availablequantity),
      __PREFIX___category: Number(item.__PREFIX___category),
      statecode: Number(item.statecode),
      location: locationNames.get(item.___PREFIX___locationid_value ?? "") ?? "",
    }));
  }, [items, locationRecords]);

  const createMutation = useMutation({
    mutationFn: async () => {
      return __PASCAL___warehouseitemsService.create({
        __PREFIX___name: name,
        __PREFIX___sku: sku,
        __PREFIX___availablequantity: String(quantity),
        __PREFIX___category: category as any,
        ...(locationId
          ? { "__PREFIX___locationid@odata.bind": `/__PREFIX___warehouselocations(${locationId})` }
          : {}),
      } as any);
    },
    onSuccess: async () => {
      await queryClient.refetchQueries({ queryKey: ["warehouseItems"] });
      toast.success("Item created successfully");
      resetForm();
    },
    onError: (err) => {
      toast.error("Failed to create item: " + String(err));
    },
  });

  const resetForm = () => {
    setDialogOpen(false);
    setName("");
    setSku("");
    setQuantity(null);
    setCategory(null);
    setLocationId("");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !sku || quantity === null || category === null) {
      toast.error("Please fill all required fields");
      return;
    }
    createMutation.mutate();
  };

  return (
    <div className={styles.page}>
      <PageHeader
        icon={<BoxRegular />}
        title="Warehouse Items"
        subtitle="Manage your warehouse inventory"
        actions={
          <>
            <Button
              appearance="outline"
              icon={<ArrowClockwiseRegular />}
              aria-label="Refresh"
              onClick={() =>
                queryClient.invalidateQueries({ queryKey: ["warehouseItems"] })
              }
            />
            <Button appearance="primary" icon={<AddRegular />} onClick={() => setDialogOpen(true)}>
              New Item
            </Button>
          </>
        }
      />

      {error && (
        <MessageBar intent="error">
          <MessageBarBody>Failed to load items: {String(error)}</MessageBarBody>
        </MessageBar>
      )}

      {isLoading ? (
        <Skeleton>
          <SkeletonItem size={48} />
        </Skeleton>
      ) : (
        <RecordGrid
          rows={rows}
          columns={columns}
          entityName="__PREFIX___warehouseitem"
          primaryIdAttribute="__PREFIX___warehouseitemid"
          primaryNameAttribute="__PREFIX___name"
          rowClassName="warehouse-item-row"
          onOpenRecord={(id) => navigate(`/items/${id}`)}
        />
      )}

      <Dialog open={dialogOpen} onOpenChange={(_, data) => setDialogOpen(data.open)}>
        <DialogSurface>
          {/* noValidate: the required-field check (and its toast) lives in handleSubmit */}
          <form onSubmit={handleSubmit} noValidate>
            <DialogBody>
              <DialogTitle>Create New Item</DialogTitle>
              <DialogContent className={styles.form}>
                <Field label="Name" required>
                  <TextField
                    context={context}
                    parameters={{ value: { raw: name, type: "SingleLine.Text" } }}
                    onNotifyOutputChanged={(outputs) => setName(outputs.value ?? "")}
                    onOverrideComponentProps={(props) => ({ ...props, id: "name" })}
                  />
                </Field>
                <Field label="SKU" required>
                  <TextField
                    context={context}
                    parameters={{ value: { raw: sku, type: "SingleLine.Text" } }}
                    onNotifyOutputChanged={(outputs) => setSku(outputs.value ?? "")}
                    onOverrideComponentProps={(props) => ({ ...props, id: "sku" })}
                  />
                </Field>
                <Field label="Available Quantity" required>
                  <Decimal
                    context={context}
                    parameters={{ value: { raw: quantity, type: "Whole.None" } }}
                    // Unparsable input arrives as the raw text: treat it as no value
                    onNotifyOutputChanged={(outputs) =>
                      setQuantity(typeof outputs.value === "number" ? outputs.value : null)
                    }
                    onOverrideComponentProps={(props) => ({ ...props, id: "quantity" })}
                  />
                </Field>
                <Field label="Category" required>
                  <OptionSet
                    context={context}
                    parameters={{ value: optionSetProperty(category, categoryOptionMetadata) }}
                    onNotifyOutputChanged={(outputs) => setCategory(outputs.value ?? null)}
                  />
                </Field>
                <Field label="Location">
                  <RecordLookup
                    entityName="__PREFIX___warehouselocation"
                    displayName="Location"
                    records={locationRecords}
                    value={locationId}
                    onChange={setLocationId}
                    inputId="location"
                  />
                </Field>
              </DialogContent>
              <DialogActions>
                <Button type="button" appearance="secondary" onClick={resetForm}>
                  Cancel
                </Button>
                <Button type="submit" appearance="primary" disabled={createMutation.isPending}>
                  {createMutation.isPending ? "Creating..." : "Create"}
                </Button>
              </DialogActions>
            </DialogBody>
          </form>
        </DialogSurface>
      </Dialog>
    </div>
  );
}
