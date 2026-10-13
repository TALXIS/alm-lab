import { useMemo, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { __PASCAL___warehouselocationsService } from "@/generated/services/__PASCAL___warehouselocationsService";
import { __PASCAL___warehouseitemsService } from "@/generated/services/__PASCAL___warehouseitemsService";
import type { __PASCAL___warehouselocations } from "@/generated/models/__PASCAL___warehouselocationsModel";
import type { __PASCAL___warehouseitems } from "@/generated/models/__PASCAL___warehouseitemsModel";
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
import { LocationRegular, AddRegular, ArrowClockwiseRegular } from "@fluentui/react-icons";
import { Decimal, TextField, usePcfContext } from "@talxis/base-controls";
import type { IColumn } from "@talxis/client-libraries";
import { PageHeader } from "@/components/PageHeader";
import { RecordGrid } from "@/components/RecordGrid";
import { statusOptions } from "@/utils/optionSets";
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
  { name: "__PREFIX___name", displayName: "Name", dataType: "SingleLine.Text", isPrimary: true, visualSizeFactor: 200 },
  { name: "__PREFIX___address", displayName: "Address", dataType: "SingleLine.Text", visualSizeFactor: 260 },
  { name: "__PREFIX___capacity", displayName: "Capacity", dataType: "Whole.None", visualSizeFactor: 110 },
  { name: "itemCount", displayName: "Items", dataType: "Whole.None", visualSizeFactor: 90 },
  { name: "active", displayName: "Active", dataType: "OptionSet", visualSizeFactor: 110, metadata: { OptionSet: statusOptions } as IColumn["metadata"] },
];

export default function LocationsPage() {
  const styles = useStyles();
  const toast = useToast();
  const context = usePcfContext();
  const queryClient = useQueryClient();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [name, setName] = useState("");
  const [address, setAddress] = useState("");
  const [capacity, setCapacity] = useState<number | null>(null);

  const { data: locations, isLoading, error } = useQuery({
    queryKey: ["warehouseLocationsList"],
    queryFn: async () => {
      const result = await __PASCAL___warehouselocationsService.getAll({
        select: [
          "__PREFIX___warehouselocationid",
          "__PREFIX___name",
          "__PREFIX___address",
          "__PREFIX___capacity",
          "__PREFIX___isactive",
          "statecode",
        ],
        orderBy: ["__PREFIX___name asc"],
      });
      return result.data ?? [];
    },
  });

  const { data: items } = useQuery({
    queryKey: ["itemsByLocation"],
    queryFn: async () => {
      const result = await __PASCAL___warehouseitemsService.getAll({
        select: ["__PREFIX___warehouseitemid", "___PREFIX___locationid_value"],
      });
      return result.data ?? [];
    },
  });

  // Grid rows: per-location item counts, numeric capacity, and isactive as an Active/Inactive option
  const rows = useMemo(() => {
    if (!locations) return undefined;
    const itemCounts = new Map<string, number>();
    (items ?? []).forEach((item: __PASCAL___warehouseitems) => {
      const locId = item.___PREFIX___locationid_value;
      if (locId) itemCounts.set(locId, (itemCounts.get(locId) ?? 0) + 1);
    });
    return locations.map((loc: __PASCAL___warehouselocations) => ({
      ...loc,
      __PREFIX___capacity: loc.__PREFIX___capacity != null ? Number(loc.__PREFIX___capacity) : null,
      itemCount: itemCounts.get(loc.__PREFIX___warehouselocationid) ?? 0,
      active: loc.__PREFIX___isactive ? 0 : 1,
    }));
  }, [locations, items]);

  const createMutation = useMutation({
    mutationFn: async () => {
      return __PASCAL___warehouselocationsService.create({
        __PREFIX___name: name,
        __PREFIX___address: address,
        __PREFIX___capacity: capacity !== null ? String(capacity) : undefined,
        __PREFIX___isactive: true,
      } as any);
    },
    onSuccess: async () => {
      await queryClient.refetchQueries({ queryKey: ["warehouseLocationsList"] });
      toast.success("Location created successfully");
      resetForm();
    },
    onError: (err) => {
      toast.error("Failed to create location: " + String(err));
    },
  });

  const resetForm = () => {
    setDialogOpen(false);
    setName("");
    setAddress("");
    setCapacity(null);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name) {
      toast.error("Please fill all required fields");
      return;
    }
    createMutation.mutate();
  };

  return (
    <div className={styles.page}>
      <PageHeader
        icon={<LocationRegular />}
        title="Locations"
        subtitle="Warehouse locations and their stock"
        actions={
          <>
            <Button
              appearance="outline"
              icon={<ArrowClockwiseRegular />}
              aria-label="Refresh"
              onClick={() =>
                queryClient.refetchQueries({ queryKey: ["warehouseLocationsList"] })
              }
            />
            <Button appearance="primary" icon={<AddRegular />} onClick={() => setDialogOpen(true)}>
              New Location
            </Button>
          </>
        }
      />

      {error && (
        <MessageBar intent="error">
          <MessageBarBody>Failed to load locations: {String(error)}</MessageBarBody>
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
          entityName="__PREFIX___warehouselocation"
          primaryIdAttribute="__PREFIX___warehouselocationid"
          primaryNameAttribute="__PREFIX___name"
        />
      )}

      <Dialog open={dialogOpen} onOpenChange={(_, data) => setDialogOpen(data.open)}>
        <DialogSurface>
          {/* noValidate: the required-field check (and its toast) lives in handleSubmit */}
          <form onSubmit={handleSubmit} noValidate>
            <DialogBody>
              <DialogTitle>Create New Location</DialogTitle>
              <DialogContent className={styles.form}>
                <Field label="Name" required>
                  <TextField
                    context={context}
                    parameters={{ value: { raw: name, type: "SingleLine.Text" } }}
                    onNotifyOutputChanged={(outputs) => setName(outputs.value ?? "")}
                    onOverrideComponentProps={(props) => ({ ...props, id: "locName" })}
                  />
                </Field>
                <Field label="Address">
                  <TextField
                    context={context}
                    parameters={{ value: { raw: address, type: "SingleLine.Text" } }}
                    onNotifyOutputChanged={(outputs) => setAddress(outputs.value ?? "")}
                    onOverrideComponentProps={(props) => ({ ...props, id: "locAddress" })}
                  />
                </Field>
                <Field label="Capacity">
                  <Decimal
                    context={context}
                    parameters={{ value: { raw: capacity, type: "Whole.None" } }}
                    // Unparsable input arrives as the raw text: treat it as no value
                    onNotifyOutputChanged={(outputs) =>
                      setCapacity(typeof outputs.value === "number" ? outputs.value : null)
                    }
                    onOverrideComponentProps={(props) => ({ ...props, id: "locCapacity" })}
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
