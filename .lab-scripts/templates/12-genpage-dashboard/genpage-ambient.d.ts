// Ambient module declarations for the GenPage local transpile step.
//
// The DevKit GenPage build invokes tsc directly on page.tsx:
//   npx tsc page.tsx --target ES5 --module ES2020 --jsx react --lib ES2015,DOM ...
// Passing the file on the command line makes tsc ignore tsconfig.json, and the
// invocation sets no --moduleResolution, so classic resolution is in effect: bare
// specifiers are never looked up in node_modules. Without these declarations every
// import below fails with TS2792, and MSBuild surfaces tsc's output as build errors
// even though the transpile itself succeeds.
//
// React, Fluent UI and the icon set are provided by the Power Apps GenPage host at
// runtime — they are not bundled from here — so declaring them loosely is enough to
// let the transpile resolve the imports. Editor IntelliSense comes from the real
// packages when you run `npm install` (node_modules is gitignored).

declare module 'react' {
  const React: any;
  export default React;
  // Real signatures, not `any`: the page calls useState<T>() with an explicit type
  // argument, and TypeScript rejects type arguments on an untyped call (TS2347).
  export function useState<S>(
    initialState: S | (() => S)
  ): [S, (value: S | ((prev: S) => S)) => void];
  export function useEffect(
    effect: () => void | (() => void),
    deps?: ReadonlyArray<unknown>
  ): void;
  export function useMemo<T>(factory: () => T, deps?: ReadonlyArray<unknown>): T;
  export function useCallback<T>(callback: T, deps?: ReadonlyArray<unknown>): T;
  export function useRef<T>(initialValue: T): { current: T };
}

declare module '@fluentui/react-components' {
  export const makeStyles: any;
  export const tokens: any;
  export const Title1: any;
  export const Card: any;
  export const CardHeader: any;
  export const Text: any;
  export const Spinner: any;
  export const Badge: any;
  export const Table: any;
  export const TableHeader: any;
  export const TableRow: any;
  export const TableHeaderCell: any;
  export const TableBody: any;
  export const TableCell: any;
  export const TableCellLayout: any;
  export const MessageBar: any;
  export const MessageBarBody: any;
  export const MessageBarTitle: any;
}

declare module '@fluentui/react-icons' {
  export const BoxRegular: any;
  export const LocationRegular: any;
  export const WarningRegular: any;
}
