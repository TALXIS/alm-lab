import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { __PASCAL___warehousetransactionsService } from "@/generated/services/__PASCAL___warehousetransactionsService";
import { __PASCAL___warehouseitemsService } from "@/generated/services/__PASCAL___warehouseitemsService";
import type { __PASCAL___warehousetransactions } from "@/generated/models/__PASCAL___warehousetransactionsModel";
import type { __PASCAL___warehouseitems } from "@/generated/models/__PASCAL___warehouseitemsModel";
import { transactionTypeLabels, transactionTypeOptions } from "@/utils/optionSets";
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
import { ArrowSwapRegular, AddRegular, ArrowClockwiseRegular } from "@fluentui/react-icons";
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

export default function TransactionsPage() {
  const styles = useStyles();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [txName, setTxName] = useState("");
  const [txQuantity, setTxQuantity] = useState("");
  const [txType, setTxType] = useState("");
  const [txItemId, setTxItemId] = useState("");

  const { data: transactions, isLoading, error } = useQuery({
    queryKey: ["allTransactions"],
    queryFn: async () => {
      const result = await __PASCAL___warehousetransactionsService.getAll({
        select: [
          "__PREFIX___warehousetransactionid",
          "__PREFIX___name",
          "__PREFIX___quantity",
          "__PREFIX___transactiontype",
          "__PREFIX___transactiondate",
          "statecode",
        ],
        orderBy: ["__PREFIX___transactiondate desc"],
      });
      return result.data ?? [];
    },
  });

  const { data: items } = useQuery({
    queryKey: ["warehouseItemsLookup"],
    queryFn: async () => {
      const result = await __PASCAL___warehouseitemsService.getAll({
        select: ["__PREFIX___warehouseitemid", "__PREFIX___name"],
        filter: "statecode eq 0",
        orderBy: ["__PREFIX___name asc"],
      });
      return result.data ?? [];
    },
  });

  const createMutation = useMutation({
    mutationFn: async () => {
      return __PASCAL___warehousetransactionsService.create({
        __PREFIX___name: txName,
        __PREFIX___quantity: txQuantity,
        __PREFIX___transactiontype: Number(txType) as any,
        __PREFIX___transactiondate: new Date().toISOString(),
        "__PREFIX___itemid@odata.bind": `/__PREFIX___warehouseitems(${txItemId})`,
      } as any);
    },
    onSuccess: async () => {
      await queryClient.refetchQueries({ queryKey: ["allTransactions"] });
      toast.success("Transaction created successfully");
      resetForm();
    },
    onError: (err) => {
      toast.error("Failed to create transaction: " + String(err));
    },
  });

  const resetForm = () => {
    setDialogOpen(false);
    setTxName("");
    setTxQuantity("");
    setTxType("");
    setTxItemId("");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!txName || !txQuantity || !txType || !txItemId) {
      toast.error("Please fill all required fields");
      return;
    }
    createMutation.mutate();
  };

  return (
    <div className={styles.page}>
      <PageHeader
        icon={<ArrowSwapRegular />}
        title="Transactions"
        subtitle="All warehouse transactions"
        actions={
          <>
            <Button
              appearance="outline"
              icon={<ArrowClockwiseRegular />}
              aria-label="Refresh"
              onClick={() =>
                queryClient.refetchQueries({ queryKey: ["allTransactions"] })
              }
            />
            <Button appearance="primary" icon={<AddRegular />} onClick={() => setDialogOpen(true)}>
              New Transaction
            </Button>
          </>
        }
      />

      {error && (
        <MessageBar intent="error">
          <MessageBarBody>Failed to load transactions: {String(error)}</MessageBarBody>
        </MessageBar>
      )}

      <div className={styles.tableWrapper}>
        <Table aria-label="Transactions">
          <TableHeader>
            <TableRow>
              <TableHeaderCell>Name</TableHeaderCell>
              <TableHeaderCell className={styles.numericHeader}>Quantity</TableHeaderCell>
              <TableHeaderCell>Type</TableHeaderCell>
              <TableHeaderCell>Status</TableHeaderCell>
              <TableHeaderCell>Date</TableHeaderCell>
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
            ) : transactions && transactions.length > 0 ? (
              transactions.map((tx: __PASCAL___warehousetransactions) => (
                <TableRow key={tx.__PREFIX___warehousetransactionid}>
                  <TableCell className={styles.name}>{tx.__PREFIX___name}</TableCell>
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
                  <TableCell>
                    <Badge
                      appearance="filled"
                      color={tx.statecode === 0 ? "success" : "danger"}
                    >
                      {tx.statecode === 0 ? "Active" : "Inactive"}
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
                <TableCell colSpan={5} className={styles.empty}>
                  No transactions found
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
              <DialogTitle>Create New Transaction</DialogTitle>
              <DialogContent className={styles.form}>
                <Field label="Name" required>
                  <Input
                    id="txName"
                    value={txName}
                    onChange={(_, data) => setTxName(data.value)}
                    placeholder="Enter transaction name"
                  />
                </Field>
                <Field label="Warehouse Item" required>
                  <Dropdown
                    placeholder="Select item"
                    value={
                      (items ?? []).find(
                        (item: __PASCAL___warehouseitems) => item.__PREFIX___warehouseitemid === txItemId
                      )?.__PREFIX___name ?? ""
                    }
                    selectedOptions={txItemId ? [txItemId] : []}
                    onOptionSelect={(_, data) => setTxItemId(data.optionValue ?? "")}
                  >
                    {(items ?? []).map((item: __PASCAL___warehouseitems) => (
                      <Option
                        key={item.__PREFIX___warehouseitemid}
                        value={item.__PREFIX___warehouseitemid}
                        text={item.__PREFIX___name ?? ""}
                      >
                        {item.__PREFIX___name}
                      </Option>
                    ))}
                  </Dropdown>
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
