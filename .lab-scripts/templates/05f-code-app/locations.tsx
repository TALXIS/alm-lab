import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { __PASCAL___warehouselocationsService } from "@/generated/services/__PASCAL___warehouselocationsService";
import { __PASCAL___warehouseitemsService } from "@/generated/services/__PASCAL___warehouseitemsService";
import type { __PASCAL___warehouselocations } from "@/generated/models/__PASCAL___warehouselocationsModel";
import type { __PASCAL___warehouseitems } from "@/generated/models/__PASCAL___warehouseitemsModel";
import {
  Badge,
  Button,
  Dialog,
  DialogActions,
  DialogBody,
  DialogContent,
  DialogSurface,
  DialogTitle,
  Field,
  Input,
  MessageBar,
  MessageBarBody,
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
import { LocationRegular, AddRegular, ArrowClockwiseRegular } from "@fluentui/react-icons";
import { PageHeader } from "@/components/PageHeader";
import { useToast } from "@/hooks/use-toast";

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
  name: {
    fontWeight: tokens.fontWeightSemibold,
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

export default function LocationsPage() {
  const styles = useStyles();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [name, setName] = useState("");
  const [address, setAddress] = useState("");
  const [capacity, setCapacity] = useState("");

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

  const itemCounts = new Map<string, number>();
  (items ?? []).forEach((item: __PASCAL___warehouseitems) => {
    const locId = item.___PREFIX___locationid_value;
    if (locId) itemCounts.set(locId, (itemCounts.get(locId) ?? 0) + 1);
  });

  const createMutation = useMutation({
    mutationFn: async () => {
      return __PASCAL___warehouselocationsService.create({
        __PREFIX___name: name,
        __PREFIX___address: address,
        __PREFIX___capacity: capacity,
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
    setCapacity("");
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

      <div className={styles.tableWrapper}>
        <Table aria-label="Locations">
          <TableHeader>
            <TableRow>
              <TableHeaderCell>Name</TableHeaderCell>
              <TableHeaderCell>Address</TableHeaderCell>
              <TableHeaderCell className={styles.numericHeader}>Capacity</TableHeaderCell>
              <TableHeaderCell className={styles.numericHeader}>Items</TableHeaderCell>
              <TableHeaderCell>Active</TableHeaderCell>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              Array.from({ length: 5 }).map((_, i) => (
                <TableRow key={i}>
                  {Array.from({ length: 5 }).map((_, j) => (
                    <TableCell key={j}>
                      <Skeleton>
                        <SkeletonItem />
                      </Skeleton>
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : locations && locations.length > 0 ? (
              locations.map((loc: __PASCAL___warehouselocations) => (
                <TableRow key={loc.__PREFIX___warehouselocationid}>
                  <TableCell className={styles.name}>
                    {loc.__PREFIX___name}
                  </TableCell>
                  <TableCell className={styles.muted}>
                    {loc.__PREFIX___address || "-"}
                  </TableCell>
                  <TableCell className={styles.numeric}>
                    {loc.__PREFIX___capacity ?? "-"}
                  </TableCell>
                  <TableCell className={styles.numeric}>
                    {itemCounts.get(loc.__PREFIX___warehouselocationid) ?? 0}
                  </TableCell>
                  <TableCell>
                    <Badge
                      appearance="filled"
                      color={loc.__PREFIX___isactive ? "success" : "danger"}
                    >
                      {loc.__PREFIX___isactive ? "Active" : "Inactive"}
                    </Badge>
                  </TableCell>
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={5} className={styles.empty}>
                  No locations found
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
              <DialogTitle>Create New Location</DialogTitle>
              <DialogContent className={styles.form}>
                <Field label="Name" required>
                  <Input
                    id="locName"
                    value={name}
                    onChange={(_, data) => setName(data.value)}
                    placeholder="Enter location name"
                  />
                </Field>
                <Field label="Address">
                  <Input
                    id="locAddress"
                    value={address}
                    onChange={(_, data) => setAddress(data.value)}
                    placeholder="Enter address"
                  />
                </Field>
                <Field label="Capacity">
                  <Input
                    id="locCapacity"
                    type="number"
                    min="0"
                    value={capacity}
                    onChange={(_, data) => setCapacity(data.value)}
                    placeholder="0"
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
