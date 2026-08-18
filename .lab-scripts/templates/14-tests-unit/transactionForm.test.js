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
  const form = makeForm({ '__PREFIX___transactiondate': dateAttr });

  WarehouseScripts.TransactionForm.onLoad(makeExecutionContext(form));

  expect(dateAttr.setValue).toHaveBeenCalledTimes(1);
  const value = dateAttr.setValue.mock.calls[0][0];
  expect(typeof value.getTime).toBe('function');
});

test('onLoad keeps an already filled transaction date', () => {
  const { WarehouseScripts } = loadWebResource(process.env.WEBRES_PATH);
  const dateAttr = makeAttr('2026-01-01');
  const form = makeForm({ '__PREFIX___transactiondate': dateAttr });

  WarehouseScripts.TransactionForm.onLoad(makeExecutionContext(form));

  expect(dateAttr.setValue).not.toHaveBeenCalled();
});

test('onQuantityChange recalculates total value from unit price', async () => {
  const { WarehouseScripts } = loadWebResource(process.env.WEBRES_PATH);
  const totalAttr = makeAttr(null);
  const form = makeForm({
    '__PREFIX___quantity': makeAttr(4),
    '__PREFIX___itemid': makeLookup({
      id: '{e3588fd9-c98c-4c13-9b75-5ff09688b468}',
      entityType: '__PREFIX___warehouseitem',
      name: 'Item A'
    }),
    '__PREFIX___totalvalue': totalAttr
  });
  Xrm.WebApi.retrieveRecord.mockResolvedValue({ __PREFIX___unitprice: 25 });

  await WarehouseScripts.TransactionForm.onQuantityChange(makeExecutionContext(form));

  expect(Xrm.WebApi.retrieveRecord).toHaveBeenCalledWith(
    '__PREFIX___warehouseitem',
    'e3588fd9-c98c-4c13-9b75-5ff09688b468',
    '?$select=__PREFIX___unitprice'
  );
  expect(totalAttr.setValue).toHaveBeenCalledWith(100);
});