#
# ╔════════════════════════════════════════════════════════════════════════════════════════╗
# ║              14: Unit Tests — Plugin (FakeXrmEasy) and Script (Jest) Projects          ║
# ╚════════════════════════════════════════════════════════════════════════════════════════╝
#
# Creates Tests.Plugins (FakeXrmEasy in-memory Dataverse) and Tests.Scripts (Jest with a
# mocked Xrm) with tests adapted to the warehouse plugins and form scripts.
# Expects: $PublisherPrefix from parent scope.
#
# ──────────────────────────────────────────────────────────────────────────────────────────
#                                    Tests.Plugins
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Tests.Plugins ──" -ForegroundColor Cyan

$prefix = $PublisherPrefix

if (-not (Get-LabValue 'pluginsTestsScaffolded')) {

# The pp-plugin-test template's Cleanup post-action expects .template.temp to exist and
# fails (rolling everything back) when it doesn't - pre-create it as a workaround.
New-Item -ItemType Directory -Path "src/Tests.Plugins/.template.temp" -Force | Out-Null

txc workspace component create pp-plugin-test `
    --output "src/Tests.Plugins"

dotnet sln add src/Tests.Plugins

cd src/Tests.Plugins
# Tests.Plugins targets net10.0 (FakeXrmEasy v3) but Plugins.Warehouse targets net462 -
# the Dataverse plugin sandbox is still .NET Framework, so that side can't move (see the
# constraint note near the top of CP14-implement-unit-tests.ps1). `dotnet add reference`
# refuses to link projects across that gap: it runs its own net10.0-vs-net462 compatibility
# preflight and there is no bypass flag, not even `-f`/`--framework` (checked). The actual
# build doesn't share that limitation - NuGet's asset target fallback resolves the net462
# reference fine, which is why `dotnet build`/`dotnet test` further down print a NU1702
# warning ("resolved using .NETFramework,Version=v4.7.2 instead of..."). That warning is
# expected and benign here - don't "fix" it by trying to retarget either project. So skip
# the CLI and add the <ProjectReference> element to the csproj XML directly instead.
$testCsproj = "Tests.Plugins.csproj"
[xml]$csprojXml = Get-Content $testCsproj -Raw
$namespaceUri = $csprojXml.DocumentElement.NamespaceURI
$itemGroup = $csprojXml.CreateElement("ItemGroup", $namespaceUri)
$projectReference = $csprojXml.CreateElement("ProjectReference", $namespaceUri)
$projectReference.SetAttribute("Include", "../Plugins.Warehouse/Plugins.Warehouse.csproj")
$itemGroup.AppendChild($projectReference) | Out-Null
$csprojXml.Project.AppendChild($itemGroup) | Out-Null
$csprojXml.Save((Resolve-Path $testCsproj))
cd ../..

Write-Host "  ✓ Tests.Plugins project (FakeXrmEasy)" -ForegroundColor Green

# Tests adapted to OUR plugins: both require ${prefix}_transactiontype in the Target,
# validation only guards Outbound (100000001), and Inbound (100000000) adds stock.
$validateTests = @"
using System;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using FakeXrmEasy.Plugins;
using Plugins.Warehouse;

namespace Tests.Plugins
{
    [TestClass]
    public class ValidateWarehouseTransactionPluginTests : FakeXrmEasyTestBase
    {
        private const int Inbound = 100000000;
        private const int Outbound = 100000001;

        private Entity SeedItem(int available)
        {
            var item = new Entity("${prefix}_warehouseitem") { Id = Guid.NewGuid() };
            item["${prefix}_availablequantity"] = available;
            _context.Initialize(new[] { item });
            return item;
        }

        private Entity MakeTransaction(Guid itemId, int quantity, int type)
        {
            var transaction = new Entity("${prefix}_warehousetransaction") { Id = Guid.NewGuid() };
            transaction["${prefix}_quantity"] = quantity;
            transaction["${prefix}_itemid"] = new EntityReference("${prefix}_warehouseitem", itemId);
            transaction["${prefix}_transactiontype"] = new OptionSetValue(type);
            return transaction;
        }

        private void Execute(Entity target)
        {
            var pluginContext = _context.GetDefaultPluginContext();
            pluginContext.MessageName = "Create";
            pluginContext.PrimaryEntityName = "${prefix}_warehousetransaction";
            pluginContext.InputParameters["Target"] = target;

            var plugin = new ValidateWarehouseTransactionPlugin(string.Empty, string.Empty);
            _context.ExecutePluginWith(pluginContext, plugin);
        }

        [TestMethod]
        public void Outbound_With_Enough_Stock_Does_Not_Throw()
        {
            var item = SeedItem(available: 10);

            Execute(MakeTransaction(item.Id, quantity: 3, Outbound));

            var reloaded = _service.Retrieve("${prefix}_warehouseitem", item.Id, new ColumnSet("${prefix}_availablequantity"));
            Assert.AreEqual(10, reloaded.GetAttributeValue<int>("${prefix}_availablequantity"));
        }

        [TestMethod]
        public void Outbound_With_Too_High_Quantity_Throws()
        {
            var item = SeedItem(available: 5);

            var ex = Assert.ThrowsExactly<InvalidPluginExecutionException>(
                () => Execute(MakeTransaction(item.Id, quantity: 10, Outbound)));

            StringAssert.Contains(ex.Message, "Not enough product in stock");
            StringAssert.Contains(ex.Message, "Available: 5");
            StringAssert.Contains(ex.Message, "requested: 10");
        }

        [TestMethod]
        public void Inbound_Is_Not_Validated()
        {
            var item = SeedItem(available: 0);

            // Inbound transactions add stock, so quantity above availability is fine.
            Execute(MakeTransaction(item.Id, quantity: 100, Inbound));
        }
    }
}
"@

Set-Content -Path "src/Tests.Plugins/ValidateWarehouseTransactionPluginTests.cs" -Value $validateTests -Encoding UTF8
Write-Host "  ✓ ValidateWarehouseTransactionPluginTests.cs" -ForegroundColor Green

$subtractTests = @"
using System;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using FakeXrmEasy.Plugins;
using Plugins.Warehouse;

namespace Tests.Plugins
{
    [TestClass]
    public class SubtractQuantityPluginTests : FakeXrmEasyTestBase
    {
        private const int Inbound = 100000000;
        private const int Outbound = 100000001;

        private Entity SeedItem(int available)
        {
            var item = new Entity("${prefix}_warehouseitem") { Id = Guid.NewGuid() };
            item["${prefix}_availablequantity"] = available;
            _context.Initialize(new[] { item });
            return item;
        }

        private void Execute(Guid itemId, int quantity, int type)
        {
            var transaction = new Entity("${prefix}_warehousetransaction") { Id = Guid.NewGuid() };
            transaction["${prefix}_quantity"] = quantity;
            transaction["${prefix}_itemid"] = new EntityReference("${prefix}_warehouseitem", itemId);
            transaction["${prefix}_transactiontype"] = new OptionSetValue(type);

            var pluginContext = _context.GetDefaultPluginContext();
            pluginContext.MessageName = "Create";
            pluginContext.PrimaryEntityName = "${prefix}_warehousetransaction";
            pluginContext.InputParameters["Target"] = transaction;

            var plugin = new SubtractQuantityPlugin(string.Empty, string.Empty);
            _context.ExecutePluginWith(pluginContext, plugin);
        }

        private int AvailableQuantity(Guid itemId) =>
            _service.Retrieve("${prefix}_warehouseitem", itemId, new ColumnSet("${prefix}_availablequantity"))
                .GetAttributeValue<int>("${prefix}_availablequantity");

        [TestMethod]
        public void Outbound_Subtracts_Quantity_From_Item()
        {
            var item = SeedItem(available: 10);

            Execute(item.Id, quantity: 3, Outbound);

            Assert.AreEqual(7, AvailableQuantity(item.Id));
        }

        [TestMethod]
        public void Inbound_Adds_Quantity_To_Item()
        {
            var item = SeedItem(available: 10);

            Execute(item.Id, quantity: 5, Inbound);

            Assert.AreEqual(15, AvailableQuantity(item.Id));
        }
    }
}
"@

Set-Content -Path "src/Tests.Plugins/SubtractQuantityPluginTests.cs" -Value $subtractTests -Encoding UTF8
Write-Host "  ✓ SubtractQuantityPluginTests.cs" -ForegroundColor Green

# Marks the block done — checked instead of Test-Path on the csproj so a re-run after a
# partial failure (e.g. project created but the csproj XML patch or test files didn't
# finish) retries everything rather than silently skipping the missing work.
Set-LabValue 'pluginsTestsScaffolded' $true

} else {
    Write-Host "  ✓ Plugins.Tests (exists)" -ForegroundColor Green
}

# ──────────────────────────────────────────────────────────────────────────────────────────
#                                    Tests.Scripts
# ──────────────────────────────────────────────────────────────────────────────────────────

Write-Host "`n── Tests.Scripts ──" -ForegroundColor Cyan

if (-not (Get-LabValue 'scriptsTestsScaffolded')) {

# ScriptLibraryPath points at the rollup bundle Scripts.UI builds - the same file that
# ships as the web resource is the file under test.
txc workspace component create pp-test-script `
    --output "src/Tests.Scripts" `
    --param "ScriptTestProjectName=Tests.Scripts" `
    --param "ScriptLibraryPath=../Scripts.UI/build/${prefix}_main.js"

dotnet sln add src/Tests.Scripts

Write-Host "  ✓ Tests.Scripts project (Jest)" -ForegroundColor Green

# Jest 30 does not expose global.jest to the template's setupXrm, so the Xrm functions a
# test relies on are assigned as jest.fn() explicitly in beforeEach (same as dev-loops CFN).
$formTests = @"
const core = require(process.env.JETS_CORE);

const { makeAttr, makeLookup, makeForm, makeExecutionContext } = core;
const { loadWebResource } = require('./utils/loadWebRes');

beforeAll(() => core.setupXrm());

beforeEach(() => {
  core.resetXrmMocks();
  Xrm.WebApi.retrieveRecord = jest.fn();
});

test('onLoad defaults transaction date to today when empty', () => {
  const { WarehouseScripts } = loadWebResource(process.env.WEBRES_PATH);
  const dateAttr = makeAttr(null);
  const form = makeForm({ '${prefix}_transactiondate': dateAttr });

  WarehouseScripts.TransactionForm.onLoad(makeExecutionContext(form));

  expect(dateAttr.setValue).toHaveBeenCalledTimes(1);
  const value = dateAttr.setValue.mock.calls[0][0];
  expect(typeof value.getTime).toBe('function');
});

test('onLoad keeps an already filled transaction date', () => {
  const { WarehouseScripts } = loadWebResource(process.env.WEBRES_PATH);
  const dateAttr = makeAttr('2026-01-01');
  const form = makeForm({ '${prefix}_transactiondate': dateAttr });

  WarehouseScripts.TransactionForm.onLoad(makeExecutionContext(form));

  expect(dateAttr.setValue).not.toHaveBeenCalled();
});

test('onQuantityChange recalculates total value from unit price', async () => {
  const { WarehouseScripts } = loadWebResource(process.env.WEBRES_PATH);
  const totalAttr = makeAttr(null);
  const form = makeForm({
    '${prefix}_quantity': makeAttr(4),
    '${prefix}_itemid': makeLookup({
      id: '{e3588fd9-c98c-4c13-9b75-5ff09688b468}',
      entityType: '${prefix}_warehouseitem',
      name: 'Item A'
    }),
    '${prefix}_totalvalue': totalAttr
  });
  Xrm.WebApi.retrieveRecord.mockResolvedValue({ ${prefix}_unitprice: 25 });

  await WarehouseScripts.TransactionForm.onQuantityChange(makeExecutionContext(form));

  expect(Xrm.WebApi.retrieveRecord).toHaveBeenCalledWith(
    '${prefix}_warehouseitem',
    'e3588fd9-c98c-4c13-9b75-5ff09688b468',
    '?`$select=${prefix}_unitprice'
  );
  expect(totalAttr.setValue).toHaveBeenCalledWith(100);
});
"@

Set-Content -Path "src/Tests.Scripts/tests/transactionForm.test.js" -Value $formTests -Encoding UTF8
Write-Host "  ✓ tests/transactionForm.test.js" -ForegroundColor Green

$ribbonTests = @"
const core = require(process.env.JETS_CORE);

const { makeAttr, makeForm } = core;
const { loadWebResource } = require('./utils/loadWebRes');

beforeAll(() => core.setupXrm());

beforeEach(() => {
  core.resetXrmMocks();
  Xrm.Navigation.openAlertDialog = jest.fn();
});

test('checkStockLevels warns when stock is at or below reorder point', async () => {
  const { WarehouseScripts } = loadWebResource(process.env.WEBRES_PATH);
  const form = makeForm({
    '${prefix}_name': makeAttr('Printer'),
    '${prefix}_availablequantity': makeAttr(3),
    '${prefix}_reorderpoint': makeAttr(5)
  });

  await WarehouseScripts.RibbonActions.checkStockLevels(form);

  expect(Xrm.Navigation.openAlertDialog).toHaveBeenCalledTimes(1);
  const dialog = Xrm.Navigation.openAlertDialog.mock.calls[0][0];
  expect(dialog.title).toBe('Stock Check');
  expect(dialog.text).toContain('Stock level for Printer: 3 units.');
  expect(dialog.text).toContain('Below reorder point (5)');
});

test('checkStockLevels reports healthy stock above reorder point', async () => {
  const { WarehouseScripts } = loadWebResource(process.env.WEBRES_PATH);
  const form = makeForm({
    '${prefix}_name': makeAttr('Monitor'),
    '${prefix}_availablequantity': makeAttr(20),
    '${prefix}_reorderpoint': makeAttr(5)
  });

  await WarehouseScripts.RibbonActions.checkStockLevels(form);

  const dialog = Xrm.Navigation.openAlertDialog.mock.calls[0][0];
  expect(dialog.text).toContain('Stock is above reorder point (5)');
});
"@

Set-Content -Path "src/Tests.Scripts/tests/ribbonActions.test.js" -Value $ribbonTests -Encoding UTF8
Write-Host "  ✓ tests/ribbonActions.test.js" -ForegroundColor Green

# Marks the block done — checked instead of Test-Path on the project directory so a re-run
# after a partial failure retries everything rather than silently skipping missing work.
Set-LabValue 'scriptsTestsScaffolded' $true

} else {
    Write-Host "  ✓ Scripts.Tests (exists)" -ForegroundColor Green
}
