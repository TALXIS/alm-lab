using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using System;

namespace Plugins.Warehouse
{
    public class ValidateWarehouseTransactionPlugin : PluginBase
    {
        public ValidateWarehouseTransactionPlugin(string unsecureConfiguration, string secureConfiguration)
            : base(typeof(ValidateWarehouseTransactionPlugin))
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
            var tracingService = localPluginContext.TracingService;

            if (!(context.InputParameters.Contains("Target") && context.InputParameters["Target"] is Entity target) || target.LogicalName != "almlab_warehousetransaction")
                return;

            if (!target.Contains("almlab_quantity") || !target.Contains("almlab_itemid") || !target.Contains("almlab_transactiontype"))
                return;

            // Only validate outbound transactions 
            var transactionType = (OptionSetValue)target["almlab_transactiontype"];
            if (transactionType.Value != 100000001)
                return;

            try
            {
                var quantity = (int)target["almlab_quantity"];
                var itemRef = (EntityReference)target["almlab_itemid"];

                var item = service.Retrieve("almlab_warehouseitem", itemRef.Id, new ColumnSet("almlab_availablequantity"));

                int available = 0;
                if (item != null && item.Contains("almlab_availablequantity"))
                {
                    available = (int)item["almlab_availablequantity"];
                }

                if (quantity > available)
                {
                    throw new InvalidPluginExecutionException(
                        $"Not enough product in stock. Available: {available}, requested: {quantity}.");
                }
            }
            catch (InvalidPluginExecutionException)
            {
                throw;
            }
            catch (Exception ex)
            {
                tracingService.Trace("Plugin Exception: {0}", ex.ToString());
                throw;
            }
        }
    }
}
