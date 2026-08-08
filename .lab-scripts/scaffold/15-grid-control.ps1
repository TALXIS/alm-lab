#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║             15: TALXIS Grid — PCF overlay + Script Library customization               ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Overlays the TALXIS Grid PCF control on the "Warehouse Items" subgrid of the
# Warehouse Location form, then customizes it at runtime from our own Scripts.UI
# web resource through the control's Client API bridge:
#
#   FormXml:  ClientApiWebresourceName = almlab_main.js
#             ClientApiFunctionName    = WarehouseScripts.GridApi.onDatasetControlInitialized
#   The PCF calls that function once its dataset exists; our script registers
#   interceptors (rename a column) and record expressions (paint low-stock cells red).
#
# The Grid control itself ships as a public Package Deployer package on nuget.org
# (TALXIS.Controls.Grid.Package) — we download it here and CP15 imports it into Dev
# BEFORE the app package, because the patched form now references the control.
#
# Expects: $PublisherPrefix from parent scope.
#
# ──────────────────────────────────────────────────────────────────────────────────────────
#                       Download the TALXIS Grid control package
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── TALXIS Grid package ──" -ForegroundColor Cyan

$prefix = $PublisherPrefix

# Pinned so the webinar/lab never breaks on a newer release renaming parameters.
$gridVersion  = "0.0.2602.15"
$tmpGrid      = Join-Path $LabRoot ".lab-scripts/.tmp-grid"
Remove-Item $tmpGrid -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $tmpGrid -Force | Out-Null

$gridNupkg = Join-Path $tmpGrid "grid.nupkg"
Invoke-WebRequest "https://api.nuget.org/v3-flatcontainer/talxis.controls.grid.package/$gridVersion/talxis.controls.grid.package.$gridVersion.nupkg" -OutFile $gridNupkg
Expand-Archive $gridNupkg -DestinationPath (Join-Path $tmpGrid "pkg") -Force

# The nupkg wraps a Package Deployer package (pdpkg.zip) with the managed TALXISPCFGrid solution.
$gridPdpkgPath = (Get-ChildItem (Join-Path $tmpGrid "pkg/contentFiles") -Filter "*.pdpkg.zip" -Recurse | Select-Object -First 1).FullName
if (-not $gridPdpkgPath) { Write-Host "  ✗ pdpkg.zip not found inside the Grid nupkg" -ForegroundColor Red; exit 1 }

Write-Host "  ✓ TALXIS.Controls.Grid.Package $gridVersion downloaded" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                Recover artifacts generated in CP09 (form, view, relationship)
# ──────────────────────────────────────────────────────────────────────────────────────────

# Form GUIDs are generated fresh in CP09 and not persisted — recover them from the
# FormXml file names, the same way 05d recovers view GUIDs.
$locationFormFile = Get-ChildItem "src/Solutions.UI/Entities/${prefix}_warehouselocation/FormXml/main/*.xml" | Select-Object -First 1
if (-not $locationFormFile) { Write-Host "  ✗ Warehouse Location form not found — run CP09 first" -ForegroundColor Red; exit 1 }
$locationFormGuid = $locationFormFile.BaseName.Trim('{}')

# The 1:N relationship behind the location lookup (CP06). Wiring it into the subgrid
# makes the grid show only THIS location's items — CP09 left it empty (unfiltered).
$relationshipName = ""
$relationshipFile = "src/Solutions.DataModel/Other/Relationships/${prefix}_warehouselocation.xml"
if (Test-Path $relationshipFile) {
    $relationshipXml  = [xml](Get-Content $relationshipFile -Raw)
    $relationshipName = ($relationshipXml.EntityRelationships.EntityRelationship |
        Where-Object { $_.ReferencingAttributeName -eq "${prefix}_locationid" } |
        Select-Object -First 1).Name
}
if ($relationshipName) {
    Write-Host "  ✓ Relationship: $relationshipName" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Location↔item relationship not found — grid will show all items" -ForegroundColor Yellow
}

# ──────────────────────────────────────────────────────────────────────────────────────────
#            Add Reorder Point to the item view (data for the low-stock rule)
# ──────────────────────────────────────────────────────────────────────────────────────────

$itemViewFile = Get-ChildItem "src/Solutions.UI/Entities/${prefix}_warehouseitem/SavedQueries/*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$itemViewXml  = [xml](Get-Content $itemViewFile.FullName -Raw)
if (-not $itemViewXml.SelectSingleNode("//cell[@name='${prefix}_reorderpoint']")) {
    $cell = $itemViewXml.CreateElement("cell")
    $cell.SetAttribute("name", "${prefix}_reorderpoint")
    $cell.SetAttribute("width", "125")
    $itemViewXml.SelectSingleNode("//row").AppendChild($cell) | Out-Null

    $attr = $itemViewXml.CreateElement("attribute")
    $attr.SetAttribute("name", "${prefix}_reorderpoint")
    $itemViewXml.SelectSingleNode("//entity").AppendChild($attr) | Out-Null

    $itemViewXml.Save($itemViewFile.FullName)
}
Write-Host "  ✓ Item view includes ${prefix}_reorderpoint" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                    Scripts.UI: Client API bridge + grid customization
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Scripts.UI: GridApi ──" -ForegroundColor Cyan

# Typings only (import type) — the runtime objects come from the PCF at call time,
# so nothing from these packages ends up in the bundle. The two extra @types are
# peer type-dependencies of @talxis/client-libraries' declarations.
cd src/Scripts.UI
npm pkg set "devDependencies.@talxis/client-libraries=^1.2606.5" `
            "devDependencies.@types/powerapps-component-framework=^1.3.15" `
            "devDependencies.@microsoft/microsoft-graph-types=^2.40.0"
npm install --no-audit --no-fund | Out-Null
cd ../..
Write-Host "  ✓ @talxis/client-libraries typings (devDependency)" -ForegroundColor Green

$gridCustomizerScript = @"
import type { IColumn, IDataset, IRecord } from '@talxis/client-libraries';

// Fallback threshold for rows that have no reorder point set
const LOW_STOCK_FALLBACK = 10;
const LOW_STOCK_BACKGROUND = '#FDE7E9';

const initialized = new Map<string, IDataset>();
const waiters = new Map<string, ((dataset: IDataset) => void)[]>();
const anyWaiters: ((dataset: IDataset) => void)[] = [];

export class GridApi {
    /**
     * Invoked by the TALXIS Grid PCF (ClientApiFunctionName in FormXml) once the
     * control has created its dataset. Registers our customizations and resolves
     * any pending getDataset() callers.
     */
    public static onDatasetControlInitialized(parameters: { controlId: string, dataset: IDataset }): void {
        const { controlId, dataset } = parameters;
        initialized.set(controlId, dataset);
        waiters.get(controlId)?.forEach(resolve => resolve(dataset));
        waiters.delete(controlId);
        anyWaiters.splice(0).forEach(resolve => resolve(dataset));
        dataset.addEventListener('onDestroyed', () => initialized.delete(controlId));
        GridApi.customizeItemsGrid(dataset);
    }

    /**
     * Resolves with the grid's dataset instance — before or after the control
     * initializes. Omit controlId when the form hosts a single grid.
     */
    public static getDataset(controlId?: string): Promise<IDataset> {
        if (!controlId) {
            const firstDataset = Array.from(initialized.values())[0];
            if (firstDataset) return Promise.resolve(firstDataset);
            return new Promise(resolve => anyWaiters.push(resolve));
        }
        const existing = initialized.get(controlId);
        if (existing) return Promise.resolve(existing);
        return new Promise(resolve => {
            const list = waiters.get(controlId) ?? [];
            list.push(resolve);
            waiters.set(controlId, list);
        });
    }

    private static customizeItemsGrid(dataset: IDataset): void {
        // Interceptor: rename the quantity column header
        dataset.setInterceptor('columns', (columns: IColumn[]) => columns.map(column =>
            column.name === '${prefix}_availablequantity'
                ? { ...column, displayName: 'Qty on hand' }
                : column));

        // Record expression: paint quantity cells red when stock is at or below reorder point
        dataset.addEventListener('onRecordLoaded', (record: IRecord) => {
            record.expressions?.ui.setCustomFormattingExpression('${prefix}_availablequantity', () => {
                const quantity = (record.getValue('${prefix}_availablequantity') as number) ?? 0;
                const reorderPoint = (record.getValue('${prefix}_reorderpoint') as number) ?? LOW_STOCK_FALLBACK;
                if (quantity > reorderPoint) return undefined;
                return { backgroundColor: LOW_STOCK_BACKGROUND };
            });
        });
    }
}

export class LocationForm {
    /**
     * OnLoad handler for the Warehouse Location main form — the consumer side of
     * the bridge: awaits the grid's dataset and surfaces its record count.
     */
    public static async onLoad(executionContext: Xrm.Events.EventContext): Promise<void> {
        const formContext = executionContext.getFormContext();
        const dataset = await GridApi.getDataset();
        const showCount = () => formContext.ui.setFormNotification(
            'TALXIS Grid ready — ' + dataset.sortedRecordIds.length + ' warehouse item(s) loaded',
            'INFO', 'talxisgrid');
        dataset.addEventListener('onFirstDataLoaded', showCount);
        if (dataset.sortedRecordIds.length > 0) showCount();
    }
}
"@

Set-Content -Path "src/Scripts.UI/src/GridCustomizer.ts" -Value $gridCustomizerScript -Encoding UTF8

$indexPath = "src/Scripts.UI/src/index.ts"
if (-not (Select-String -Path $indexPath -Pattern "GridCustomizer" -Quiet)) {
    Add-Content -Path $indexPath -Value "`nexport { GridApi, LocationForm } from './GridCustomizer';" -Encoding UTF8
}
Write-Host "  ✓ GridCustomizer.ts (GridApi bridge + LocationForm)" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#              Register onLoad handler (also adds almlab_main.js to the form)
# ──────────────────────────────────────────────────────────────────────────────────────────

# The template's post-scripts add the Library to <formLibraries> — required, because
# the form must load the web resource before the PCF can call into it.
txc workspace component create pp-form-event-handler `
    --output "src/Solutions.UI" `
    --param "FormType=main" `
    --param "FormId=$locationFormGuid" `
    --param "EntityLogicalName=${prefix}_warehouselocation" `
    --param "LibraryName=${prefix}_main" `
    --param "FunctionName=WarehouseScripts.LocationForm.onLoad" `
    --param "EventType=onload"

Write-Host "  ✓ Event handler: warehouselocation form → onLoad" -ForegroundColor Green

# ──────────────────────────────────────────────────────────────────────────────────────────
#                 FormXml: overlay TALXIS Grid on the items subgrid
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── FormXml overlay ──" -ForegroundColor Cyan

# No pp-* template exists for attaching a custom control to a form control yet
# (pp-control is a placeholder), so we patch the FormXml DOM directly — the same
# approach 05d uses for view columns. The target shape mirrors production TALXIS
# solutions: a <controlDescription> for the subgrid's uniqueid with an empty base
# control block plus one talxis_TALXIS.PCF.Grid block per form factor.
$formXml = [xml](Get-Content $locationFormFile.FullName -Raw)

if ($formXml.SelectSingleNode("//controlDescriptions")) {
    Write-Host "  ⚠ controlDescriptions already present — skipping overlay patch" -ForegroundColor Yellow
} else {
    $subgridControl = $formXml.SelectSingleNode("//control[@indicationOfSubgrid='true']")
    if (-not $subgridControl) { Write-Host "  ✗ Items subgrid not found on the location form" -ForegroundColor Red; exit 1 }
    $subgridUniqueId = $subgridControl.GetAttribute('uniqueid')
    $viewId          = $subgridControl.SelectSingleNode('parameters/ViewId').InnerText

    # Fix the CP09 gap while we're here: an empty RelationshipName means the subgrid
    # shows ALL items; with the relationship set it shows only this location's items.
    if ($relationshipName) {
        $subgridControl.SelectSingleNode('parameters/RelationshipName').InnerText = $relationshipName
    }

    # Group by category, sum the quantity, keep reorder point available but hidden.
    $columnsJson = "[ { `"name`": `"${prefix}_category`", `"grouping`": { `"isGrouped`": true } }, { `"name`": `"${prefix}_availablequantity`", `"aggregation`": { `"aggregationFunction`": `"sum`" } }, { `"name`": `"${prefix}_reorderpoint`", `"isHidden`": true } ]"

    $gridParameters = @"
<parameters>
  <data-set name="Grid">
    <ViewId>$viewId</ViewId>
    <TargetEntityType>${prefix}_warehouseitem</TargetEntityType>
    <IsUserView>false</IsUserView>
    <EnableViewPicker>false</EnableViewPicker>
    <RelationshipName>$relationshipName</RelationshipName>
    <FilteredViewIds>$viewId</FilteredViewIds>
  </data-set>
  <Columns type="Multiple" static="true">$columnsJson</Columns>
  <RowHeight type="Whole.None" static="true">42</RowHeight>
  <EnableEditing type="Enum" static="true">false</EnableEditing>
  <EnablePagination type="Enum" static="true">true</EnablePagination>
  <EnableFiltering type="Enum" static="true">true</EnableFiltering>
  <EnableSorting type="Enum" static="true">true</EnableSorting>
  <EnableNavigation type="Enum" static="true">true</EnableNavigation>
  <EnableOptionSetColors type="Enum" static="true">true</EnableOptionSetColors>
  <EnableAggregation type="Enum" static="true">true</EnableAggregation>
  <EnableAutoSave type="Enum" static="true">false</EnableAutoSave>
  <SelectableRows type="Enum" static="true">single</SelectableRows>
  <EnablePageSizeSwitcher type="Enum" static="true">true</EnablePageSizeSwitcher>
  <EnableGrouping type="Enum" static="true">true</EnableGrouping>
  <EnableGroupedColumnsPinning type="Enum" static="true">true</EnableGroupedColumnsPinning>
  <EnableRecordCount type="Enum" static="true">true</EnableRecordCount>
  <EnableZebra type="Enum" static="true">true</EnableZebra>
  <DefaultExpandedGroupLevel type="Whole.None" static="true">-1</DefaultExpandedGroupLevel>
  <GroupingType type="Enum" static="true">nested</GroupingType>
  <ClientApiWebresourceName type="SingleLine.Text" static="true">${prefix}_main.js</ClientApiWebresourceName>
  <ClientApiFunctionName type="SingleLine.Text" static="true">WarehouseScripts.GridApi.onDatasetControlInitialized</ClientApiFunctionName>
</parameters>
"@

    $controlDescriptionsRaw = @"
<controlDescriptions>
  <controlDescription forControl="$subgridUniqueId">
    <customControl id="{E7A81278-8635-4D9E-8D4D-59480B391C5B}">
      <parameters />
    </customControl>
    <customControl formFactor="0" name="talxis_TALXIS.PCF.Grid">$gridParameters</customControl>
    <customControl formFactor="1" name="talxis_TALXIS.PCF.Grid">$gridParameters</customControl>
    <customControl formFactor="2" name="talxis_TALXIS.PCF.Grid">$gridParameters</customControl>
  </controlDescription>
</controlDescriptions>
"@

    $fragment = [xml]$controlDescriptionsRaw
    $imported = $formXml.ImportNode($fragment.DocumentElement, $true)
    $formNode = $formXml.SelectSingleNode("//form")

    # Production forms order it: controlDescriptions → DisplayConditions → formLibraries → events
    $anchor = $formXml.SelectSingleNode("//form/DisplayConditions")
    if (-not $anchor) { $anchor = $formXml.SelectSingleNode("//form/formLibraries") }
    if ($anchor) { $formNode.InsertBefore($imported, $anchor) | Out-Null } else { $formNode.AppendChild($imported) | Out-Null }

    $formXml.Save($locationFormFile.FullName)
    Write-Host "  ✓ talxis_TALXIS.PCF.Grid overlaid on the Warehouse Items subgrid" -ForegroundColor Green
}

# ──────────────────────────────────────────────────────────────────────────────────────────
#                              Jest tests for the bridge
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Scripts.Tests: gridApi ──" -ForegroundColor Cyan

$gridTests = @"
const core = require(process.env.JETS_CORE);

const { loadWebResource } = require('./utils/loadWebRes');

beforeAll(() => core.setupXrm());

beforeEach(() => core.resetXrmMocks());

const makeDataset = () => ({
  setInterceptor: jest.fn(),
  addEventListener: jest.fn(),
});

test('getDataset resolves once the grid initializes', async () => {
  const { WarehouseScripts } = loadWebResource(process.env.WEBRES_PATH);
  const dataset = makeDataset();

  const promise = WarehouseScripts.GridApi.getDataset('subgrid');
  WarehouseScripts.GridApi.onDatasetControlInitialized({ controlId: 'subgrid', dataset });

  await expect(promise).resolves.toBe(dataset);
});

test('getDataset resolves immediately when the grid is already initialized', async () => {
  const { WarehouseScripts } = loadWebResource(process.env.WEBRES_PATH);
  const dataset = makeDataset();

  WarehouseScripts.GridApi.onDatasetControlInitialized({ controlId: 'subgrid', dataset });

  await expect(WarehouseScripts.GridApi.getDataset('subgrid')).resolves.toBe(dataset);
});

test('getDataset without controlId resolves with the only grid on the form', async () => {
  const { WarehouseScripts } = loadWebResource(process.env.WEBRES_PATH);
  const dataset = makeDataset();

  const promise = WarehouseScripts.GridApi.getDataset();
  WarehouseScripts.GridApi.onDatasetControlInitialized({ controlId: 'subgrid', dataset });

  await expect(promise).resolves.toBe(dataset);
});

test('columns interceptor renames the quantity column', () => {
  const { WarehouseScripts } = loadWebResource(process.env.WEBRES_PATH);
  const dataset = makeDataset();

  WarehouseScripts.GridApi.onDatasetControlInitialized({ controlId: 'subgrid', dataset });

  const [event, interceptor] = dataset.setInterceptor.mock.calls[0];
  expect(event).toBe('columns');

  const columns = interceptor([
    { name: '${prefix}_availablequantity', displayName: 'Available Quantity' },
    { name: '${prefix}_sku', displayName: 'SKU' }
  ]);
  expect(columns[0].displayName).toBe('Qty on hand');
  expect(columns[1].displayName).toBe('SKU');
});

test('low-stock rows get custom formatting on the quantity cell', () => {
  const { WarehouseScripts } = loadWebResource(process.env.WEBRES_PATH);
  const dataset = makeDataset();

  WarehouseScripts.GridApi.onDatasetControlInitialized({ controlId: 'subgrid', dataset });

  const onRecordLoaded = dataset.addEventListener.mock.calls.find(c => c[0] === 'onRecordLoaded')[1];
  const expressions = { ui: { setCustomFormattingExpression: jest.fn() } };
  const values = { '${prefix}_availablequantity': 5, '${prefix}_reorderpoint': 10 };
  onRecordLoaded({ getValue: (name) => values[name], expressions });

  const [column, formattingExpression] = expressions.ui.setCustomFormattingExpression.mock.calls[0];
  expect(column).toBe('${prefix}_availablequantity');
  expect(formattingExpression()).toEqual({ backgroundColor: expect.any(String) });

  values['${prefix}_availablequantity'] = 50;
  expect(formattingExpression()).toBeUndefined();
});
"@

Set-Content -Path "src/Scripts.Tests/tests/gridApi.test.js" -Value $gridTests -Encoding UTF8
Write-Host "  ✓ tests/gridApi.test.js" -ForegroundColor Green
