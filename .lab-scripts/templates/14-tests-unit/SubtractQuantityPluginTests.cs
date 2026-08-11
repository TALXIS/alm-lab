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
            var item = new Entity("__PREFIX___warehouseitem") { Id = Guid.NewGuid() };
            item["__PREFIX___availablequantity"] = available;
            _context.Initialize(new[] { item });
            return item;
        }

        private void Execute(Guid itemId, int quantity, int type)
        {
            var transaction = new Entity("__PREFIX___warehousetransaction") { Id = Guid.NewGuid() };
            transaction["__PREFIX___quantity"] = quantity;
            transaction["__PREFIX___itemid"] = new EntityReference("__PREFIX___warehouseitem", itemId);
            transaction["__PREFIX___transactiontype"] = new OptionSetValue(type);

            var pluginContext = _context.GetDefaultPluginContext();
            pluginContext.MessageName = "Create";
            pluginContext.PrimaryEntityName = "__PREFIX___warehousetransaction";
            pluginContext.InputParameters["Target"] = transaction;

            var plugin = new SubtractQuantityPlugin(string.Empty, string.Empty);
            _context.ExecutePluginWith(pluginContext, plugin);
        }

        private int AvailableQuantity(Guid itemId) =>
            _service.Retrieve("__PREFIX___warehouseitem", itemId, new ColumnSet("__PREFIX___availablequantity"))
                .GetAttributeValue<int>("__PREFIX___availablequantity");

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