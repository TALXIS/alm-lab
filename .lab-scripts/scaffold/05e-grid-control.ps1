#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║             05e: TALXIS Grid — PCF overlay + Script Library customization              ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Overlays the TALXIS Grid PCF control on the "Warehouse Items" subgrid of the
# Warehouse Location form via `txc workspace control attach` — the CLI reads the
# parameter schema from the control's own ControlManifest.xml (no per-control
# template needed) — then customizes the grid at runtime from our own Scripts.UI
# web resource through the control's Client API bridge:
#
#   FormXml:  ClientApiWebresourceName = almlab_main.js
#             ClientApiFunctionName    = WarehouseScripts.GridApi.onDatasetControlInitialized
#   The PCF calls that function once its dataset exists; our script registers
#   interceptors (rename a column) and record expressions (paint low-stock cells red).
#
# The Grid control itself ships as a public Package Deployer package on nuget.org
# (TALXIS.Controls.Grid.Package). Nothing is downloaded by hand and no version is
# pinned: `control attach` resolves the latest version of the NuGet package itself,
# and CP10 imports the same package into Dev by name BEFORE the app package, because
# the patched form now references the control.
#
# Expects: $PublisherPrefix from parent scope (after 05a–05d and 09-form-scripts),
#          TALXIS.CLI with `workspace control attach`.

$prefix = $PublisherPrefix
$gridPackage = "TALXIS.Controls.Grid.Package"

# ──────────────────────────────────────────────────────────────────────────────────────────
#                     Recover generated artifacts (form, view)
# ──────────────────────────────────────────────────────────────────────────────────────────

# Form GUIDs are generated fresh in 05c and not persisted — recover them from the
# FormXml file names, the same way 05d recovers view GUIDs.
$locationFormFile = Get-ChildItem "src/Solutions.UI/Entities/${prefix}_warehouselocation/FormXml/main/*.xml" | Select-Object -First 1
if (-not $locationFormFile) { Write-Host "  ✗ Warehouse Location form not found — run CP09 first" -ForegroundColor Red; exit 1 }
$locationFormGuid = $locationFormFile.BaseName.Trim('{}')

# ──────────────────────────────────────────────────────────────────────────────────────────
#            Add Reorder Point to the item view (data for the low-stock rule)
# ──────────────────────────────────────────────────────────────────────────────────────────

$itemViewFile = Get-ChildItem "src/Solutions.UI/Entities/${prefix}_warehouseitem/SavedQueries/*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $itemViewFile) { Write-Host "  ✗ Warehouse Item view not found — run CP09 first" -ForegroundColor Red; exit 1 }
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
if ($LASTEXITCODE -ne 0) { Write-Host "  ⚠ npm install had issues (exit code: $LASTEXITCODE)" -ForegroundColor Yellow }
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

        // Record expression: paint quantity cells red when stock is at or below reorder point.
        // Group-header pseudo-records and empty cells have no quantity value — leave them alone.
        dataset.addEventListener('onRecordLoaded', (record: IRecord) => {
            record.expressions?.ui.setCustomFormattingExpression('${prefix}_availablequantity', () => {
                const quantity = record.getValue('${prefix}_availablequantity');
                if (quantity == null) return undefined;
                const reorderPoint = (record.getValue('${prefix}_reorderpoint') as number) ?? LOW_STOCK_FALLBACK;
                if ((quantity as number) > reorderPoint) return undefined;
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
#                 Attach TALXIS Grid to the items subgrid (manifest-driven)
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Grid overlay (txc workspace control attach) ──" -ForegroundColor Cyan

# The attach command copies the subgrid's binding (view + RelationshipName, set by
# pp-form-subgrid in 05d) into the grid — nothing is patched by hand here.
# No per-control template and no manual download: the CLI pulls the package from
# nuget.org, reads the parameter schema straight from its ControlManifest.xml,
# validates the values, and writes the controlDescriptions overlay into the form
# (one customControl block per form factor). Unspecified parameters keep the
# control's manifest defaults.
# Columns: group by category, sum the quantity, keep reorder point available but hidden.
$columnsJson = "[ { `"name`": `"${prefix}_category`", `"grouping`": { `"isGrouped`": true } }, { `"name`": `"${prefix}_availablequantity`", `"aggregation`": { `"aggregationFunction`": `"sum`" } }, { `"name`": `"${prefix}_reorderpoint`", `"isHidden`": true } ]"

txc workspace control attach `
    --output "src/Solutions.UI" `
    --entity "${prefix}_warehouselocation" `
    --form-id $locationFormGuid `
    --target-control "subgrid" `
    --package $gridPackage `
    --param "Columns=$columnsJson" `
    --param "EnableGrouping=true" `
    --param "EnableAggregation=true" `
    --param "EnableOptionSetColors=true" `
    --param "ClientApiWebresourceName=${prefix}_main.js" `
    --param "ClientApiFunctionName=WarehouseScripts.GridApi.onDatasetControlInitialized" `
    --force

if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ txc workspace control attach failed" -ForegroundColor Red; exit 1 }
Write-Host "  ✓ talxis_TALXIS.PCF.Grid attached to the Warehouse Items subgrid" -ForegroundColor Green

