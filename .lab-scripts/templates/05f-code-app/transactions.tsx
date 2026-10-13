import { useMemo, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { __PASCAL___warehousetransactionsService } from "@/generated/services/__PASCAL___warehousetransactionsService";
import { __PASCAL___warehouseitemsService } from "@/generated/services/__PASCAL___warehouseitemsService";
import type { __PASCAL___warehousetransactions } from "@/generated/models/__PASCAL___warehousetransactionsModel";
import type { __PASCAL___warehouseitems } from "@/generated/models/__PASCAL___warehouseitemsModel";
import { statusOptions, transactionTypeOptionMetadata, optionSetProperty } from "@/utils/optionSets";
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
import { ArrowSwapRegular, AddRegular, ArrowClockwiseRegular } from "@fluentui/react-icons";
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

const transactionTypeMetadata = {
  OptionSet: transactionTypeOptionMetadata,
} as IColumn["metadata"];

const columns: IColumn[] = [
  { name: "__PREFIX___name", displayName: "Name", dataType: "SingleLine.Text", isPrimary: true, visualSizeFactor: 240 },
  { name: "__PREFIX___quantity", displayName: "Quantity", dataType: "Whole.None", visualSizeFactor: 110 },
  { name: "__PREFIX___transactiontype", displayName: "Type", dataType: "OptionSet", visualSizeFactor: 130, metadata: transactionTypeMetadata },
  { name: "statecode", displayName: "Status", dataType: "OptionSet", visualSizeFactor: 110, metadata: { OptionSet: statusOptions } as IColumn["metadata"] },
  { name: "__PREFIX___transactiondate", displayName: "Date", dataType: "DateAndTime.DateOnly", visualSizeFactor: 120 },
];

export default function TransactionsPage() {
  const styles = useStyles();
  const toast = useToast();
  const context = usePcfContext();
  const queryClient = useQueryClient();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [txName, setTxName] = useState("");
  const [txQuantity, setTxQuantity] = useState<number | null>(null);
  const [txType, setTxType] = useState<number | null>(null);
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

  const itemRecords = useMemo(
    () =>
      (items ?? []).map((item: __PASCAL___warehouseitems) => ({
        id: item.__PREFIX___warehouseitemid,
        name: item.__PREFIX___name ?? "",
      })),
    [items]
  );

  const rows = useMemo(
    () =>
      transactions?.map((tx: __PASCAL___warehousetransactions) => ({
        ...tx,
        __PREFIX___quantity: Number(tx.__PREFIX___quantity),
        __PREFIX___transactiontype: Number(tx.__PREFIX___transactiontype),
        statecode: Number(tx.statecode),
      })),
    [transactions]
  );

  const createMutation = useMutation({
    mutationFn: async () => {
      return __PASCAL___warehousetransactionsService.create({
        __PREFIX___name: txName,
        __PREFIX___quantity: String(txQuantity),
        __PREFIX___transactiontype: txType as any,
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
    setTxQuantity(null);
    setTxType(null);
    setTxItemId("");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!txName || txQuantity === null || txType === null || !txItemId) {
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

      {isLoading ? (
        <Skeleton>
          <SkeletonItem size={48} />
        </Skeleton>
      ) : (
        <RecordGrid
          rows={rows}
          columns={columns}
          entityName="__PREFIX___warehousetransaction"
          primaryIdAttribute="__PREFIX___warehousetransactionid"
          primaryNameAttribute="__PREFIX___name"
        />
      )}

      <Dialog open={dialogOpen} onOpenChange={(_, data) => setDialogOpen(data.open)}>
        <DialogSurface>
          {/* noValidate: the required-field check (and its toast) lives in handleSubmit */}
          <form onSubmit={handleSubmit} noValidate>
            <DialogBody>
              <DialogTitle>Create New Transaction</DialogTitle>
              <DialogContent className={styles.form}>
                <Field label="Name" required>
                  <TextField
                    context={context}
                    parameters={{ value: { raw: txName, type: "SingleLine.Text" } }}
                    onNotifyOutputChanged={(outputs) => setTxName(outputs.value ?? "")}
                    onOverrideComponentProps={(props) => ({ ...props, id: "txName" })}
                  />
                </Field>
                <Field label="Warehouse Item" required>
                  <RecordLookup
                    entityName="__PREFIX___warehouseitem"
                    displayName="Warehouse Item"
                    records={itemRecords}
                    value={txItemId}
                    onChange={setTxItemId}
                    inputId="txItem"
                  />
                </Field>
                <Field label="Quantity" required>
                  <Decimal
                    context={context}
                    parameters={{ value: { raw: txQuantity, type: "Whole.None" } }}
                    // Unparsable input arrives as the raw text: treat it as no value
                    onNotifyOutputChanged={(outputs) =>
                      setTxQuantity(typeof outputs.value === "number" ? outputs.value : null)
                    }
                    onOverrideComponentProps={(props) => ({ ...props, id: "txQuantity" })}
                  />
                </Field>
                <Field label="Transaction Type" required>
                  <OptionSet
                    context={context}
                    parameters={{ value: optionSetProperty(txType, transactionTypeOptionMetadata) }}
                    onNotifyOutputChanged={(outputs) => setTxType(outputs.value ?? null)}
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
