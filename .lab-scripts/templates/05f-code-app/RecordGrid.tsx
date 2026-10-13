import { useEffect, useRef, useState } from "react";
import { Grid, usePcfContext } from "@talxis/base-controls";
import { Dataset, MemoryDataProvider, type IColumn, type IRawRecord } from "@talxis/client-libraries";

type RecordGridProps = {
  /** Rows the page already loaded through the generated services; undefined while loading. */
  rows: IRawRecord[] | undefined;
  columns: IColumn[];
  entityName: string;
  primaryIdAttribute: string;
  primaryNameAttribute: string;
  /** Class put on every AG Grid row, e.g. as a stable hook for UI tests. */
  rowClassName?: string;
  /** Called with the record id when its name is clicked; without it the names aren't links. */
  onOpenRecord?: (id: string) => void;
};

// A read-only TALXIS base-controls Grid over data the code app already has: a MemoryDataProvider
// holds the rows (there's no Dataverse Web API behind a code app's PCF context), and opening a
// record is routed to onOpenRecord instead of a model-driven form.
export function RecordGrid({
  rows,
  columns,
  entityName,
  primaryIdAttribute,
  primaryNameAttribute,
  rowClassName,
  onOpenRecord,
}: RecordGridProps) {
  const context = usePcfContext();
  const onOpenRecordRef = useRef(onOpenRecord);
  useEffect(() => {
    onOpenRecordRef.current = onOpenRecord;
  });

  const [dataset] = useState(() => {
    // LogicalName becomes the entity type of opened records (the metadata type comes from Xrm's)
    const metadata = {
      LogicalName: entityName,
      PrimaryIdAttribute: primaryIdAttribute,
      PrimaryNameAttribute: primaryNameAttribute,
    };
    const provider = new MemoryDataProvider({ dataSource: [], metadata });
    const dataset = new Dataset(provider);
    dataset.setColumns(columns);
    dataset.setInterceptor("onOpenDatasetItem", (entityReference) =>
      onOpenRecordRef.current?.(entityReference.id.guid)
    );
    return dataset;
  });

  // New query results replace the provider's rows; refresh() is what makes the grid re-read them.
  useEffect(() => {
    if (!rows) return;
    dataset.setDataSource(rows);
    void dataset.refresh();
  }, [dataset, rows]);

  return (
    <Grid
      context={context}
      parameters={{
        Grid: dataset,
        SelectableRows: { raw: "none" },
        EnableNavigation: { raw: !!onOpenRecord },
        EnableOptionSetColors: { raw: true },
      }}
      onOverrideComponentProps={(props) => ({ ...props, rowClass: rowClassName })}
    />
  );
}
