using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using System;

namespace Plugins.Warehouse
{
    public class SubtractQuantityPlugin : PluginBase
    {
        public SubtractQuantityPlugin(string unsecureConfiguration, string secureConfiguration)
            : base(typeof(SubtractQuantityPlugin))
        {
        }

        protected override void ExecuteDataversePlugin(ILocalPluginContext localPluginContext)
        {
            if (localPluginContext == null)
            {
                throw new ArgumentNullException(nameof(localPluginContext));
            }

            var context = localPluginContext.PluginExecutionContext;
            var serviceFactory = localPluginContext.OrgSvcFactory;
            var service = serviceFactory.CreateOrganizationService(context.UserId);

            if (!(context.InputParameters["Target"] is Entity target) || target.LogicalName != "__PREFIX___warehousetransaction")
                return;

            if (!target.Contains("__PREFIX___quantity") || !target.Contains("__PREFIX___itemid") || !target.Contains("__PREFIX___transactiontype"))
                return;

            var quantity = (int)target["__PREFIX___quantity"];
            var itemRef = (EntityReference)target["__PREFIX___itemid"];
            var transactionType = (OptionSetValue)target["__PREFIX___transactiontype"];

            var item = service.Retrieve("__PREFIX___warehouseitem", itemRef.Id, new ColumnSet("__PREFIX___availablequantity"));
            var available = item.Contains("__PREFIX___availablequantity") ? (int)item["__PREFIX___availablequantity"] : 0;

            // Inbound (100000000) = add stock, Outbound (100000001) = subtract stock
            if (transactionType.Value == 100000000)
                item["__PREFIX___availablequantity"] = available + quantity;
            else if (transactionType.Value == 100000001)
                item["__PREFIX___availablequantity"] = available - quantity;
            else
                return;

            service.Update(item);
        }
    }
}