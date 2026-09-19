/// <reference path="./genpage-ambient.d.ts" />
// The DevKit GenPage build compiles with the classic JSX transform, so React must be
// in scope for every element in this file.
import * as React from 'react';
import { useEffect, useMemo, useState } from 'react';
import {
  makeStyles,
  Title1,
  Card,
  CardHeader,
  Text,
  Spinner,
  Badge,
  tokens,
  Table,
  TableHeader,
  TableRow,
  TableHeaderCell,
  TableBody,
  TableCell,
  TableCellLayout,
  MessageBar,
  MessageBarBody,
  MessageBarTitle,
} from '@fluentui/react-components';
import {
  BoxRegular,
  LocationRegular,
  WarningRegular,
} from '@fluentui/react-icons';
import type { GeneratedComponentProps } from './RuntimeTypes';

// Items with no reorder point of their own fall back to this before they count as low.
const LOW_STOCK_THRESHOLD = 10;

const ITEM_ENTITY = 'almlab_warehouseitem';
const LOCATION_ENTITY = 'almlab_warehouselocation';

// Cache + in-flight keys live on `window` so the genpage host's double-mount shares one
// round-trip instead of firing the query twice. Keyed per page + query, never per entity.
const winAny = window as any;
const CACHE_KEY = '__ppWarehouseDashboardCache';
const INFLIGHT_KEY = '__ppWarehouseDashboardInflight';

const FORMATTED = '@OData.Community.Display.V1.FormattedValue';

// Annotations (choice labels, lookup display names) arrive as sibling keys on the row,
// so the row type carries an index signature alongside the verified columns.
interface WarehouseItem {
  almlab_warehouseitemid: string;
  almlab_name: string;
  almlab_sku: string;
  almlab_availablequantity: number;
  almlab_reorderpoint: number | null;
  almlab_category: number | null;
  _almlab_locationid_value: string | null;
  [key: string]: unknown;
}

interface DashboardData {
  items: WarehouseItem[];
  totalLocations: number;
}

const isLowStock = (item: WarehouseItem): boolean =>
  item.almlab_availablequantity <= (item.almlab_reorderpoint ?? LOW_STOCK_THRESHOLD);

// Choice and lookup columns are numeric/GUID on the row; the label is on the annotation.
const displayValue = (item: WarehouseItem, column: string): string => {
  const formatted = item[`${column}${FORMATTED}`];
  return typeof formatted === 'string' && formatted.length > 0 ? formatted : '—';
};

const useStyles = makeStyles({
  container: {
    display: 'flex',
    flexDirection: 'column',
    gap: tokens.spacingVerticalL,
    padding: tokens.spacingHorizontalXL,
    height: '100%',
    boxSizing: 'border-box',
  },
  cardRow: {
    display: 'flex',
    gap: tokens.spacingHorizontalL,
    flexWrap: 'wrap',
  },
  summaryCard: {
    minWidth: '200px',
    flex: '1 1 200px',
  },
  cardBody: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalM,
    padding: tokens.spacingVerticalM,
  },
  cardValue: {
    fontSize: tokens.fontSizeHero800,
    fontWeight: tokens.fontWeightBold,
    lineHeight: tokens.lineHeightHero800,
  },
  lowStock: {
    color: tokens.colorPaletteRedForeground1,
  },
  tableCard: {
    display: 'flex',
    flexDirection: 'column',
    minHeight: 0,
  },
  tableScroll: {
    overflowY: 'auto',
    maxHeight: 'calc(100% - 3rem)',
  },
  emptyState: {
    padding: tokens.spacingVerticalXXL,
    textAlign: 'center',
    color: tokens.colorNeutralForeground3,
  },
});

const GeneratedComponent = (props: GeneratedComponentProps) => {
  const styles = useStyles();
  const { dataApi } = props;

  // The host hands a NEW dataApi reference every render, so effects depend on this
  // readiness flag instead - putting dataApi in a dep array re-fires on every render.
  const dataReady = !!dataApi;

  const [{ data, loading, error }, setData] = useState<{
    data: DashboardData;
    loading: boolean;
    error: string | null;
  }>(() => {
    const cached = winAny[CACHE_KEY] as DashboardData | undefined;
    return {
      data: cached ?? { items: [], totalLocations: 0 },
      loading: cached === undefined,
      error: null,
    };
  });

  useEffect(() => {
    if (!dataReady) return;

    // Read the authoritative window cache: the other mount may have resolved it
    // between this mount's render and this effect.
    const cached = winAny[CACHE_KEY] as DashboardData | undefined;
    if (cached !== undefined) {
      if (data !== cached) setData({ data: cached, loading: false, error: null });
      return;
    }

    let cancelled = false;

    let inflight = winAny[INFLIGHT_KEY] as Promise<DashboardData> | undefined;
    if (!inflight) {
      inflight = Promise.all([
        dataApi.queryTable<WarehouseItem>(ITEM_ENTITY, {
          select: [
            'almlab_warehouseitemid',
            'almlab_name',
            'almlab_sku',
            'almlab_category',
            'almlab_availablequantity',
            'almlab_reorderpoint',
            '_almlab_locationid_value',
          ],
          orderBy: 'almlab_availablequantity asc',
          pageSize: 100,
        }),
        dataApi.queryTable(LOCATION_ENTITY, {
          select: ['almlab_warehouselocationid'],
          pageSize: 100,
        }),
      ])
        .then(([itemsResult, locationsResult]) => {
          const payload: DashboardData = {
            items: itemsResult.rows,
            totalLocations: locationsResult.rows.length,
          };
          winAny[CACHE_KEY] = payload;
          return payload;
        })
        // Not .finally(): the GenPage build pins --lib ES2015, where Promise.finally
        // does not exist. Clear only if still ours - a concurrent refresh may have
        // replaced this entry with a newer promise we must not delete.
        .then(
          (payload) => {
            if (winAny[INFLIGHT_KEY] === inflight) delete winAny[INFLIGHT_KEY];
            return payload;
          },
          (err) => {
            if (winAny[INFLIGHT_KEY] === inflight) delete winAny[INFLIGHT_KEY];
            throw err;
          }
        );
      winAny[INFLIGHT_KEY] = inflight;
    }

    inflight
      .then((payload) => {
        if (!cancelled) setData({ data: payload, loading: false, error: null });
      })
      .catch(() => {
        if (!cancelled) {
          setData({
            data: { items: [], totalLocations: 0 },
            loading: false,
            error: 'Unable to load warehouse data. Refresh the page to try again.',
          });
        }
      });

    return () => {
      cancelled = true;
    };
    // Readiness only - dataApi is a new reference every render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dataReady]);

  // Every hook stays above the early returns below (React rules of hooks).
  const summary = useMemo(() => {
    const items = data.items ?? [];
    return {
      totalItems: items.length,
      totalLocations: data.totalLocations,
      lowStockCount: items.filter(isLowStock).length,
    };
  }, [data]);

  if (loading) {
    return <Spinner label="Loading dashboard..." />;
  }

  return (
    <div className={styles.container}>
      <Title1 as="h1">Warehouse dashboard</Title1>

      {error && (
        <MessageBar intent="error" role="alert">
          <MessageBarBody>
            <MessageBarTitle>Something went wrong</MessageBarTitle>
            {error}
          </MessageBarBody>
        </MessageBar>
      )}

      <section className={styles.cardRow} aria-label="Inventory summary">
        <Card className={styles.summaryCard}>
          <CardHeader header={<Text weight="semibold">Total items</Text>} />
          <div className={styles.cardBody}>
            <BoxRegular fontSize={28} aria-hidden="true" />
            <Text className={styles.cardValue}>{summary.totalItems}</Text>
          </div>
        </Card>

        <Card className={styles.summaryCard}>
          <CardHeader header={<Text weight="semibold">Locations</Text>} />
          <div className={styles.cardBody}>
            <LocationRegular fontSize={28} aria-hidden="true" />
            <Text className={styles.cardValue}>{summary.totalLocations}</Text>
          </div>
        </Card>

        <Card className={styles.summaryCard}>
          <CardHeader header={<Text weight="semibold">Low stock alerts</Text>} />
          <div className={styles.cardBody}>
            <WarningRegular fontSize={28} aria-hidden="true" />
            <Text
              className={`${styles.cardValue} ${summary.lowStockCount > 0 ? styles.lowStock : ''}`}
            >
              {summary.lowStockCount}
            </Text>
          </div>
        </Card>
      </section>

      <Card className={styles.tableCard}>
        <CardHeader header={<Text weight="semibold">Inventory overview</Text>} />
        {summary.totalItems === 0 ? (
          <div className={styles.emptyState}>
            <Text>No warehouse items yet.</Text>
          </div>
        ) : (
          <div className={styles.tableScroll}>
            <Table aria-label="Warehouse inventory, lowest stock first">
              <TableHeader>
                <TableRow>
                  <TableHeaderCell>Item name</TableHeaderCell>
                  <TableHeaderCell>SKU</TableHeaderCell>
                  <TableHeaderCell>Category</TableHeaderCell>
                  <TableHeaderCell>Location</TableHeaderCell>
                  <TableHeaderCell>Available quantity</TableHeaderCell>
                  <TableHeaderCell>Reorder point</TableHeaderCell>
                  <TableHeaderCell>Status</TableHeaderCell>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.items.map((item) => {
                  const low = isLowStock(item);
                  return (
                    <TableRow key={item.almlab_warehouseitemid}>
                      <TableCell>
                        <TableCellLayout>{item.almlab_name}</TableCellLayout>
                      </TableCell>
                      <TableCell>
                        <TableCellLayout>{item.almlab_sku}</TableCellLayout>
                      </TableCell>
                      <TableCell>
                        <TableCellLayout>
                          {displayValue(item, 'almlab_category')}
                        </TableCellLayout>
                      </TableCell>
                      <TableCell>
                        <TableCellLayout>
                          {displayValue(item, '_almlab_locationid_value')}
                        </TableCellLayout>
                      </TableCell>
                      <TableCell>
                        <TableCellLayout>
                          <Text className={low ? styles.lowStock : undefined}>
                            {item.almlab_availablequantity}
                          </Text>
                        </TableCellLayout>
                      </TableCell>
                      <TableCell>
                        <TableCellLayout>
                          {item.almlab_reorderpoint ?? '—'}
                        </TableCellLayout>
                      </TableCell>
                      <TableCell>
                        <TableCellLayout>
                          <Badge appearance="filled" color={low ? 'danger' : 'success'}>
                            {low ? 'Low stock' : 'In stock'}
                          </Badge>
                        </TableCellLayout>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        )}
      </Card>
    </div>
  );
};

export default GeneratedComponent;

