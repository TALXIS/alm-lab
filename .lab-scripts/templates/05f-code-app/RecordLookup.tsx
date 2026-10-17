import { useMemo } from "react";
import { Lookup, usePcfContext, type ILookupProperty } from "@talxis/base-controls";
import { getEntity } from "@/providers/pcf-host";

type LookupRecord = { id: string; name: string };

type RecordLookupProps = {
  /** A table registered in entities.ts (the control reads its metadata, e.g. for the placeholder). */
  entityName: string;
  /** Candidate records the page already loaded; typing filters them by name. */
  records: LookupRecord[];
  /** Selected record id, or "" for none. */
  value: string;
  onChange: (id: string) => void;
  /** id of the control's input, for labels and UI tests. */
  inputId?: string;
  /** Marks the input aria-required (the page validates on submit). */
  required?: boolean;
};

const noViews = async () => [];

// A TALXIS base-controls Lookup whose search runs over an in-memory list (onSearch) rather than
// Dataverse views and fetchXml, which a code app has no Web API for.
export function RecordLookup({ entityName, records, value, onChange, inputId, required }: RecordLookupProps) {
  const context = usePcfContext();
  const displayName = getEntity(entityName)?.displayName ?? entityName;

  const selected = records.find((record) => record.id === value);
  // Stable across renders: the Lookup derives its target entities from these attributes
  const attributes = useMemo(() => ({ Targets: [entityName], DisplayName: displayName }), [entityName, displayName]);
  const lookupValue: ILookupProperty = {
    raw: selected ? [{ entityType: entityName, id: selected.id, name: selected.name }] : [],
    attributes,
    getAllViews: noViews,
  };

  return (
    <Lookup
      context={context}
      parameters={{
        value: lookupValue,
        // Both would open model-driven forms (new record / selected record), which a code app lacks
        IsInlineNewEnabled: { raw: false },
        EnableNavigation: { raw: false },
      }}
      onSearch={async (_entityNames, query) => {
        const text = (query ?? "").toLowerCase();
        return records
          .filter((record) => record.name.toLowerCase().includes(text))
          .slice(0, 25)
          .map((record) => ({ entityType: entityName, id: record.id, name: record.name }));
      }}
      onNotifyOutputChanged={(outputs) => onChange(outputs.value?.[0]?.id ?? "")}
      onOverrideComponentProps={(props) => ({
        ...props,
        inputProps: { ...props.inputProps, id: inputId, "aria-required": required || undefined },
        // Picking a record clears the input, and the control's typing debounce then reopens the
        // suggestions resolveDelay later, after the selected tag has replaced the input, so they
        // float at the page's top-left. With one record allowed, suggestions only belong to the
        // empty field: keep their callout hidden while a record is selected.
        pickerCalloutProps: { ...props.pickerCalloutProps, hidden: !!selected },
      })}
    />
  );
}
