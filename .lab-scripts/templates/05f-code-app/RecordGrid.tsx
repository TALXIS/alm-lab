import { useEffect, useState } from "react";
import { Grid, usePcfContext } from "@talxis/base-controls";
import { Dataset, MemoryDataProvider, type IColumn, type IRawRecord } from "@talxis/client-libraries";
import { getEntity } from "@/providers/pcf-host";

type RecordGridProps = {
  /** Rows the page already loaded through the generated services; undefined while loading. */
  rows: IRawRecord[] | undefined;
  columns: IColumn[];
  /** A table registered in entities.ts; its primary columns key the rows. */
  entityName: string;
  /** Class put on every AG Grid row, e.g. as a stable hook for UI tests. */
  rowClassName?: string;
};

// A read-only TALXIS base-controls Grid over data the code app already has: a MemoryDataProvider
// holds the rows (there's no Dataverse Web API behind a code app's PCF context). Record names link
// to the entity's page when it has one, opened like any control would: context.navigation.openForm.
export function RecordGrid({ rows, columns, entityName, rowClassName }: RecordGridProps) {
  const context = usePcfContext();
  const entity = getEntity(entityName);
  if (!entity) throw new Error(`RecordGrid: '${entityName}' isn't registered in entities.ts`);

  const [dataset] = useState(() => {
    // LogicalName becomes the entity type of opened records (the metadata type comes from Xrm's)
    const metadata = {
      LogicalName: entity.logicalName,
      PrimaryIdAttribute: entity.primaryIdAttribute,
      PrimaryNameAttribute: entity.primaryNameAttribute,
    };
    const dataset = new Dataset(new MemoryDataProvider({ dataSource: [], metadata }));
    dataset.setColumns(columns);
    // A memory provider doesn't open records itself; hand them to the context like a form would
    dataset.setInterceptor("onOpenDatasetItem", (entityReference) =>
      void context.navigation.openForm({ entityName: entity.logicalName, entityId: entityReference.id.guid })
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
        EnableNavigation: { raw: !!entity.formPath },
        EnableOptionSetColors: { raw: true },
      }}
      onOverrideComponentProps={(props) => ({ ...props, rowClass: rowClassName })}
    />
  );
}
