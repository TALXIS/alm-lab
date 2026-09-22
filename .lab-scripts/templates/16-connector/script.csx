// Custom code for the Open Food Facts connector - implements Microsoft's "Script : ScriptBase"
// contract. Docs: https://learn.microsoft.com/en-us/connectors/custom-connectors/write-code
//
// Two jobs, both things the caller should never have to do themselves:
//   1. Open Food Facts requires a descriptive User-Agent header identifying the calling app
//      (see https://openfoodfacts.github.io/openfoodfacts-server/api/) - inject it here so
//      the code app never has to know about it.
//   2. The real API response nests everything under "product" and uses snake_case
//      (product_name, brands, image_url) - flatten it to match this connector's declared
//      Product schema (ean, name, brand, quantity, imageUrl) so the caller gets a simple,
//      stable shape regardless of what the backend calls its fields.
//
// Runs on .NET Standard 2.0 with a restricted namespace set - see the doc above for the full
// list. Execution must finish within 2 minutes; the compiled script can't exceed 1 MB.

using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using Newtonsoft.Json.Linq;

public class Script : ScriptBase
{
    public override async Task<HttpResponseMessage> ExecuteAsync()
    {
        this.Context.Request.Headers.UserAgent.ParseAdd("TALXIS-ALM-Lab-WarehousePicking/1.0 (+https://github.com/TALXIS/alm-lab)");

        var response = await this.Context.SendAsync(this.Context.Request, this.CancellationToken)
            .ConfigureAwait(false);

        if (!response.IsSuccessStatusCode)
        {
            return response;
        }

        var body = JObject.Parse(await response.Content.ReadAsStringAsync().ConfigureAwait(false));

        // Open Food Facts returns HTTP 200 with status:0 for an unknown barcode - it isn't a
        // transport-level error, but there's no product to flatten either. Surface it as 404
        // so the caller's error handling matches every other "not found" connector call.
        if ((int?)body["status"] != 1)
        {
            response.StatusCode = HttpStatusCode.NotFound;
            response.Content = CreateJsonContent("{\"message\": \"No product found for this barcode\"}");
            return response;
        }

        var product = body["product"];
        var flattened = new JObject
        {
            ["ean"] = (string)body["code"],
            ["name"] = (string)product["product_name"],
            ["brand"] = (string)product["brands"],
            ["quantity"] = (string)product["quantity"],
            ["imageUrl"] = (string)product["image_url"]
        };
        response.Content = CreateJsonContent(flattened.ToString());

        return response;
    }
}
