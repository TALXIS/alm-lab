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
    'almlab_name': makeAttr('Printer'),
    'almlab_availablequantity': makeAttr(3),
    'almlab_reorderpoint': makeAttr(5)
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
    'almlab_name': makeAttr('Monitor'),
    'almlab_availablequantity': makeAttr(20),
    'almlab_reorderpoint': makeAttr(5)
  });

  await WarehouseScripts.RibbonActions.checkStockLevels(form);

  const dialog = Xrm.Navigation.openAlertDialog.mock.calls[0][0];
  expect(dialog.text).toContain('Stock is above reorder point (5)');
});
