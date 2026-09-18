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
            var item = new Entity("almlab_warehouseitem") { Id = Guid.NewGuid() };
            item["almlab_availablequantity"] = available;
            _context.Initialize(new[] { item });
            return item;
        }

        private void Execute(Guid itemId, int quantity, int type)
        {
            var transaction = new Entity("almlab_warehousetransaction") { Id = Guid.NewGuid() };
            transaction["almlab_quantity"] = quantity;
            transaction["almlab_itemid"] = new EntityReference("almlab_warehouseitem", itemId);
            transaction["almlab_transactiontype"] = new OptionSetValue(type);

            var pluginContext = _context.GetDefaultPluginContext();
            pluginContext.MessageName = "Create";
            pluginContext.PrimaryEntityName = "almlab_warehousetransaction";
            pluginContext.InputParameters["Target"] = transaction;

            var plugin = new SubtractQuantityPlugin(string.Empty, string.Empty);
            _context.ExecutePluginWith(pluginContext, plugin);
        }

        private int AvailableQuantity(Guid itemId) =>
            _service.Retrieve("almlab_warehouseitem", itemId, new ColumnSet("almlab_availablequantity"))
                .GetAttributeValue<int>("almlab_availablequantity");

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
