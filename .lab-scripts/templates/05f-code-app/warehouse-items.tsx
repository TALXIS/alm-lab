import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { __PASCAL___warehouseitemsService } from "@/generated/services/__PASCAL___warehouseitemsService";
import { __PASCAL___warehouselocationsService } from "@/generated/services/__PASCAL___warehouselocationsService";
import type { __PASCAL___warehouseitems } from "@/generated/models/__PASCAL___warehouseitemsModel";
import type { __PASCAL___warehouselocations } from "@/generated/models/__PASCAL___warehouselocationsModel";
import { categoryLabels, categoryOptions } from "@/utils/optionSets";
import {
  Badge,
  Button,
  Dialog,
  DialogActions,
  DialogBody,
  DialogContent,
  DialogSurface,
  DialogTitle,
  Dropdown,
  Field,
  Input,
  MessageBar,
  MessageBarBody,
  Option,
  Skeleton,
  SkeletonItem,
  Table,
  TableBody,
  TableCell,
  TableHeader,
  TableHeaderCell,
  TableRow,
  makeStyles,
  tokens,
} from "@fluentui/react-components";
import { BoxRegular, AddRegular, ArrowClockwiseRegular } from "@fluentui/react-icons";
import { PageHeader } from "@/components/PageHeader";
import { RouterLink } from "@/components/RouterLink";
import { useNotify } from "@/hooks/use-notify";

const useStyles = makeStyles({
  page: {
    padding: tokens.spacingHorizontalXXL,
    display: "flex",
    flexDirection: "column",
    gap: tokens.spacingVerticalXL,
  },
  tableWrapper: {
    border: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
    borderRadius: tokens.borderRadiusMedium,
    overflowX: "auto",
  },
  numeric: {
    textAlign: "right",
    fontFamily: tokens.fontFamilyMonospace,
  },
  numericHeader: {
    "& > *": { justifyContent: "flex-end" },
  },
  mono: {
    fontFamily: tokens.fontFamilyMonospace,
    color: tokens.colorNeutralForeground3,
  },
  muted: {
    color: tokens.colorNeutralForeground3,
  },
  empty: {
    textAlign: "center",
    padding: `${tokens.spacingVerticalXXL} 0`,
    color: tokens.colorNeutralForeground3,
  },
  form: {
    display: "flex",
    flexDirection: "column",
    gap: tokens.spacingVerticalM,
  },
});

export default function WarehouseItemsPage() {
  const styles = useStyles();
  const notify = useNotify();
  const queryClient = useQueryClient();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [name, setName] = useState("");
  const [sku, setSku] = useState("");
  const [quantity, setQuantity] = useState("");
  const [category, setCategory] = useState("");
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

  const locationNames = new Map(
    (locations ?? []).map((loc: __PASCAL___warehouselocations) => [
      loc.__PREFIX___warehouselocationid,
      loc.__PREFIX___name,
    ])
  );

  const createMutation = useMutation({
    mutationFn: async () => {
      return __PASCAL___warehouseitemsService.create({
        __PREFIX___name: name,
        __PREFIX___sku: sku,
        __PREFIX___availablequantity: quantity,
        __PREFIX___category: Number(category) as any,
        ...(locationId
          ? { "__PREFIX___locationid@odata.bind": `/__PREFIX___warehouselocations(${locationId})` }
          : {}),
      } as any);
    },
    onSuccess: async () => {
      await queryClient.refetchQueries({ queryKey: ["warehouseItems"] });
      notify.success("Item created successfully");
      resetForm();
    },
    onError: (err) => {
      notify.error("Failed to create item: " + String(err));
    },
  });

  const resetForm = () => {
    setDialogOpen(false);
    setName("");
    setSku("");
    setQuantity("");
    setCategory("");
    setLocationId("");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !sku || !quantity || !category) {
      notify.error("Please fill all required fields");
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

      <div className={styles.tableWrapper}>
        <Table aria-label="Warehouse items">
          <TableHeader>
            <TableRow>
              <TableHeaderCell>Name</TableHeaderCell>
              <TableHeaderCell>SKU</TableHeaderCell>
              <TableHeaderCell className={styles.numericHeader}>Available Qty</TableHeaderCell>
              <TableHeaderCell>Category</TableHeaderCell>
              <TableHeaderCell>Location</TableHeaderCell>
              <TableHeaderCell>Status</TableHeaderCell>
              <TableHeaderCell>Created</TableHeaderCell>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              Array.from({ length: 5 }).map((_, i) => (
                <TableRow key={i}>
                  {Array.from({ length: 7 }).map((_, j) => (
                    <TableCell key={j}>
                      <Skeleton>
                        <SkeletonItem />
                      </Skeleton>
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : items && items.length > 0 ? (
              items.map((item: __PASCAL___warehouseitems) => (
                <TableRow key={item.__PREFIX___warehouseitemid} data-testid="warehouse-item-row">
                  <TableCell>
                    <RouterLink to={`/items/${item.__PREFIX___warehouseitemid}`}>
                      {item.__PREFIX___name}
                    </RouterLink>
                  </TableCell>
                  <TableCell className={styles.mono}>
                    {item.__PREFIX___sku}
                  </TableCell>
                  <TableCell className={styles.numeric}>
                    {item.__PREFIX___availablequantity}
                  </TableCell>
                  <TableCell>
                    <Badge appearance="tint" color="informative">
                      {categoryLabels[
                        item.__PREFIX___category as keyof typeof categoryLabels
                      ] ?? item.__PREFIX___category}
                    </Badge>
                  </TableCell>
                  <TableCell className={styles.muted}>
                    {locationNames.get(item.___PREFIX___locationid_value ?? "") ?? "-"}
                  </TableCell>
                  <TableCell>
                    <Badge
                      appearance="filled"
                      color={item.statecode === 0 ? "success" : "danger"}
                    >
                      {item.statecode === 0 ? "Active" : "Inactive"}
                    </Badge>
                  </TableCell>
                  <TableCell className={styles.muted}>
                    {item.createdon
                      ? new Date(item.createdon).toLocaleDateString()
                      : "-"}
                  </TableCell>
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={7} className={styles.empty}>
                  No warehouse items found
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      <Dialog open={dialogOpen} onOpenChange={(_, data) => setDialogOpen(data.open)}>
        <DialogSurface>
          {/* noValidate: the required-field check (and its toast) lives in handleSubmit */}
          <form onSubmit={handleSubmit} noValidate>
            <DialogBody>
              <DialogTitle>Create New Item</DialogTitle>
              <DialogContent className={styles.form}>
                <Field label="Name" required>
                  <Input
                    id="name"
                    value={name}
                    onChange={(_, data) => setName(data.value)}
                    placeholder="Enter item name"
                  />
                </Field>
                <Field label="SKU" required>
                  <Input
                    id="sku"
                    value={sku}
                    onChange={(_, data) => setSku(data.value)}
                    placeholder="Enter SKU"
                  />
                </Field>
                <Field label="Available Quantity" required>
                  <Input
                    id="quantity"
                    type="number"
                    min="0"
                    value={quantity}
                    onChange={(_, data) => setQuantity(data.value)}
                    placeholder="0"
                  />
                </Field>
                <Field label="Category" required>
                  <Dropdown
                    placeholder="Select category"
                    value={categoryOptions.find((opt) => String(opt.value) === category)?.label ?? ""}
                    selectedOptions={category ? [category] : []}
                    onOptionSelect={(_, data) => setCategory(data.optionValue ?? "")}
                  >
                    {categoryOptions.map((opt) => (
                      <Option key={opt.value} value={String(opt.value)}>
                        {opt.label}
                      </Option>
                    ))}
                  </Dropdown>
                </Field>
                <Field label="Location">
                  <Dropdown
                    placeholder="Select location (optional)"
                    value={locationNames.get(locationId) ?? ""}
                    selectedOptions={locationId ? [locationId] : []}
                    onOptionSelect={(_, data) => setLocationId(data.optionValue ?? "")}
                  >
                    {(locations ?? []).map((loc: __PASCAL___warehouselocations) => (
                      <Option
                        key={loc.__PREFIX___warehouselocationid}
                        value={loc.__PREFIX___warehouselocationid}
                        text={loc.__PREFIX___name ?? ""}
                      >
                        {loc.__PREFIX___name}
                      </Option>
                    ))}
                  </Dropdown>
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
