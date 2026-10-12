import { useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { __PASCAL___warehouseitemsService } from "@/generated/services/__PASCAL___warehouseitemsService";
import { __PASCAL___warehousetransactionsService } from "@/generated/services/__PASCAL___warehousetransactionsService";
import { __PASCAL___warehouselocationsService } from "@/generated/services/__PASCAL___warehouselocationsService";
import type { __PASCAL___warehousetransactions } from "@/generated/models/__PASCAL___warehousetransactionsModel";
import type { __PASCAL___warehouselocations } from "@/generated/models/__PASCAL___warehouselocationsModel";
import {
  categoryLabels,
  transactionTypeLabels,
  transactionTypeOptions,
} from "@/utils/optionSets";
import {
  Badge,
  Body1,
  Button,
  Card,
  Caption1,
  Dialog,
  DialogActions,
  DialogBody,
  DialogContent,
  DialogSurface,
  DialogTitle,
  Dropdown,
  Field,
  Input,
  LargeTitle,
  Option,
  Skeleton,
  SkeletonItem,
  Subtitle1,
  Subtitle2,
  Table,
  TableBody,
  TableCell,
  TableHeader,
  TableHeaderCell,
  TableRow,
  Title2,
  makeStyles,
  tokens,
} from "@fluentui/react-components";
import { ArrowLeftRegular, AddRegular, BoxRegular, ArrowSwapRegular, LocationRegular } from "@fluentui/react-icons";
import { useNotify } from "@/hooks/use-notify";

const useStyles = makeStyles({
  page: {
    padding: tokens.spacingHorizontalXXL,
    display: "flex",
    flexDirection: "column",
    gap: tokens.spacingVerticalXL,
  },
  heading: {
    display: "flex",
    alignItems: "center",
    gap: tokens.spacingHorizontalL,
  },
  headingText: {
    display: "flex",
    flexDirection: "column",
  },
  cards: {
    display: "grid",
    gap: tokens.spacingHorizontalL,
    gridTemplateColumns: "repeat(4, minmax(0, 1fr))",
    "@media (max-width: 768px)": {
      gridTemplateColumns: "minmax(0, 1fr)",
    },
  },
  toolbar: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    gap: tokens.spacingHorizontalL,
  },
  inline: {
    display: "flex",
    alignItems: "center",
    gap: tokens.spacingHorizontalS,
  },
  icon: {
    fontSize: "20px",
    color: tokens.colorNeutralForeground3,
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
  mono: {
    fontFamily: tokens.fontFamilyMonospace,
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
  skeletonTitle: {
    width: "200px",
    height: "32px",
  },
  skeletonCards: {
    height: "128px",
  },
  skeletonTable: {
    height: "256px",
  },
});

export default function WarehouseItemDetailPage() {
  const styles = useStyles();
  const notify = useNotify();
  const navigate = useNavigate();
  const { id } = useParams<{ id: string }>();
  const queryClient = useQueryClient();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [txName, setTxName] = useState("");
  const [txQuantity, setTxQuantity] = useState("");
  const [txType, setTxType] = useState("");

  const { data: item, isLoading: itemLoading } = useQuery({
    queryKey: ["warehouseItem", id],
    queryFn: async () => {
      const result = await __PASCAL___warehouseitemsService.get(id!);
      return result.data;
    },
    enabled: !!id,
  });

  const { data: transactions, isLoading: txLoading } = useQuery({
    queryKey: ["itemTransactions", id],
    queryFn: async () => {
      const result = await __PASCAL___warehousetransactionsService.getAll({
        select: [
          "__PREFIX___warehousetransactionid",
          "__PREFIX___name",
          "__PREFIX___quantity",
          "__PREFIX___transactiontype",
          "__PREFIX___transactiondate",
        ],
        filter: `___PREFIX___itemid_value eq '${id}'`,
        orderBy: ["__PREFIX___transactiondate desc"],
      });
      return result.data ?? [];
    },
    enabled: !!id,
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

  const createTxMutation = useMutation({
    mutationFn: async () => {
      return __PASCAL___warehousetransactionsService.create({
        __PREFIX___name: txName,
        __PREFIX___quantity: txQuantity,
        __PREFIX___transactiontype: Number(txType) as any,
        __PREFIX___transactiondate: new Date().toISOString(),
        "__PREFIX___itemid@odata.bind": `/__PREFIX___warehouseitems(${id})`,
      } as any);
    },
    onSuccess: async () => {
      await queryClient.refetchQueries({ queryKey: ["itemTransactions", id] });
      await queryClient.refetchQueries({ queryKey: ["warehouseItem", id] });
      notify.success("Transaction created");
      resetForm();
    },
    onError: (err) => {
      notify.error("Failed to create transaction: " + String(err));
    },
  });

  const resetForm = () => {
    setDialogOpen(false);
    setTxName("");
    setTxQuantity("");
    setTxType("");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!txName || !txQuantity || !txType) {
      notify.error("Please fill all required fields");
      return;
    }
    createTxMutation.mutate();
  };

  if (itemLoading) {
    return (
      <Skeleton className={styles.page}>
        <SkeletonItem className={styles.skeletonTitle} />
        <SkeletonItem className={styles.skeletonCards} />
        <SkeletonItem className={styles.skeletonTable} />
      </Skeleton>
    );
  }

  if (!item) {
    return (
      <div className={styles.page}>
        <Body1 className={styles.muted}>Item not found.</Body1>
        <div>
          <Button appearance="transparent" icon={<ArrowLeftRegular />} onClick={() => navigate("/")}>
            Back to items
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className={styles.page}>
      <div className={styles.heading}>
        <Button
          appearance="subtle"
          icon={<ArrowLeftRegular />}
          aria-label="Back to items"
          onClick={() => navigate("/")}
        />
        <div className={styles.headingText}>
          <Title2 as="h1">{item.__PREFIX___name}</Title2>
          <Body1 className={`${styles.muted} ${styles.mono}`}>
            {item.__PREFIX___sku}
          </Body1>
        </div>
      </div>

      <div className={styles.cards}>
        <Card>
          <Caption1 className={styles.muted}>Available Quantity</Caption1>
          <LargeTitle data-testid="item-detail-qty">
            {item.__PREFIX___availablequantity}
          </LargeTitle>
        </Card>
        <Card>
          <Caption1 className={styles.muted}>Category</Caption1>
          <div className={styles.inline}>
            <BoxRegular className={styles.icon} />
            <Subtitle1>
              {categoryLabels[
                item.__PREFIX___category as keyof typeof categoryLabels
              ] ?? item.__PREFIX___category}
            </Subtitle1>
          </div>
        </Card>
        <Card>
          <Caption1 className={styles.muted}>Location</Caption1>
          <div className={styles.inline}>
            <LocationRegular className={styles.icon} />
            <Subtitle1>
              {locationNames.get(item.___PREFIX___locationid_value ?? "") ?? "-"}
            </Subtitle1>
          </div>
        </Card>
        <Card>
          <Caption1 className={styles.muted}>Status</Caption1>
          <div>
            <Badge appearance="filled" color={item.statecode === 0 ? "success" : "danger"}>
              {item.statecode === 0 ? "Active" : "Inactive"}
            </Badge>
          </div>
        </Card>
      </div>

      <div className={styles.toolbar}>
        <div className={styles.inline}>
          <ArrowSwapRegular className={styles.icon} />
          <Subtitle2 as="h2">Transactions</Subtitle2>
        </div>
        <Button
          appearance="primary"
          size="small"
          icon={<AddRegular />}
          data-testid="new-transaction-button"
          onClick={() => setDialogOpen(true)}
        >
          New Transaction
        </Button>
      </div>

      <div className={styles.tableWrapper}>
        <Table aria-label="Item transactions">
          <TableHeader>
            <TableRow>
              <TableHeaderCell>Name</TableHeaderCell>
              <TableHeaderCell className={styles.numericHeader}>Quantity</TableHeaderCell>
              <TableHeaderCell>Type</TableHeaderCell>
              <TableHeaderCell>Date</TableHeaderCell>
            </TableRow>
          </TableHeader>
          <TableBody>
            {txLoading ? (
              Array.from({ length: 3 }).map((_, i) => (
                <TableRow key={i}>
                  {Array.from({ length: 4 }).map((_, j) => (
                    <TableCell key={j}>
                      <Skeleton>
                        <SkeletonItem />
                      </Skeleton>
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : transactions && transactions.length > 0 ? (
              transactions.map((tx: __PASCAL___warehousetransactions) => (
                <TableRow key={tx.__PREFIX___warehousetransactionid}>
                  <TableCell className={styles.name}>
                    {tx.__PREFIX___name}
                  </TableCell>
                  <TableCell className={styles.numeric}>
                    {tx.__PREFIX___quantity}
                  </TableCell>
                  <TableCell>
                    <Badge appearance="outline" color="informative">
                      {transactionTypeLabels[
                        tx.__PREFIX___transactiontype as keyof typeof transactionTypeLabels
                      ] ?? tx.__PREFIX___transactiontype}
                    </Badge>
                  </TableCell>
                  <TableCell className={styles.muted}>
                    {tx.__PREFIX___transactiondate
                      ? new Date(tx.__PREFIX___transactiondate).toLocaleDateString()
                      : "-"}
                  </TableCell>
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={4} className={styles.empty}>
                  No transactions yet
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
              <DialogTitle>New Transaction for {item.__PREFIX___name}</DialogTitle>
              <DialogContent className={styles.form}>
                <Field label="Transaction Name" required>
                  <Input
                    id="txName"
                    value={txName}
                    onChange={(_, data) => setTxName(data.value)}
                    placeholder="Enter transaction name"
                  />
                </Field>
                <Field label="Quantity" required>
                  <Input
                    id="txQuantity"
                    type="number"
                    min="0"
                    value={txQuantity}
                    onChange={(_, data) => setTxQuantity(data.value)}
                    placeholder="0"
                  />
                </Field>
                <Field label="Transaction Type" required>
                  <Dropdown
                    data-testid="tx-type-trigger"
                    placeholder="Select transaction type"
                    value={transactionTypeOptions.find((opt) => String(opt.value) === txType)?.label ?? ""}
                    selectedOptions={txType ? [txType] : []}
                    onOptionSelect={(_, data) => setTxType(data.optionValue ?? "")}
                  >
                    {transactionTypeOptions.map((opt) => (
                      <Option key={opt.value} value={String(opt.value)}>
                        {opt.label}
                      </Option>
                    ))}
                  </Dropdown>
                </Field>
              </DialogContent>
              <DialogActions>
                <Button type="button" appearance="secondary" onClick={resetForm}>
                  Cancel
                </Button>
                <Button
                  type="submit"
                  appearance="primary"
                  data-testid="submit-transaction"
                  disabled={createTxMutation.isPending}
                >
                  {createTxMutation.isPending ? "Creating..." : "Create"}
                </Button>
              </DialogActions>
            </DialogBody>
          </form>
        </DialogSurface>
      </Dialog>
    </div>
  );
}
