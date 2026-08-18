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

            if (!(context.InputParameters.Contains("Target") && context.InputParameters["Target"] is Entity target) || target.LogicalName != "__PREFIX___warehousetransaction")
                return;

            if (!target.Contains("__PREFIX___quantity") || !target.Contains("__PREFIX___itemid") || !target.Contains("__PREFIX___transactiontype"))
                return;

            // Only validate outbound transactions 
            var transactionType = (OptionSetValue)target["__PREFIX___transactiontype"];
            if (transactionType.Value != 100000001)
                return;

            try
            {
                var quantity = (int)target["__PREFIX___quantity"];
                var itemRef = (EntityReference)target["__PREFIX___itemid"];

                var item = service.Retrieve("__PREFIX___warehouseitem", itemRef.Id, new ColumnSet("__PREFIX___availablequantity"));

                int available = 0;
                if (item != null && item.Contains("__PREFIX___availablequantity"))
                {
                    available = (int)item["__PREFIX___availablequantity"];
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