// Custom code for the connector - implements Microsoft's "Script : ScriptBase" contract.
// Docs: https://learn.microsoft.com/en-us/connectors/custom-connectors/write-code
//
// Routed by Context.OperationId (scriptOperations is left empty in apiProperties.json, so
// this script runs for every operation):
//
//   GetProductByBarcode - adds the User-Agent header the backend requires, and flattens the
//     backend's nested, snake_case response into this connector's declared Product schema.
//
//   GetProductImage - proxies an image's bytes server-side, since a code app's CSP can block
//     loading an external image URL client-side. The image's host differs from the backend's
//     declared host, so the outgoing request's URI is redirected to it before sending.
//
// Runs on .NET Standard 2.0 with a restricted namespace set - see the doc above for the full
// list. Execution must finish within 2 minutes; the compiled script can't exceed 1 MB.

using System;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using Newtonsoft.Json.Linq;

public class Script : ScriptBase
{
    private const string UserAgent = "TALXIS-ALM-Lab-WarehousePicking/1.0 (+https://github.com/TALXIS/alm-lab)";

    public override async Task<HttpResponseMessage> ExecuteAsync()
    {
        if (string.Equals(this.Context.OperationId, "GetProductImage", StringComparison.OrdinalIgnoreCase))
        {
            return await GetProductImageAsync().ConfigureAwait(false);
        }

        return await GetProductByBarcodeAsync().ConfigureAwait(false);
    }

    private async Task<HttpResponseMessage> GetProductByBarcodeAsync()
    {
        this.Context.Request.Headers.UserAgent.ParseAdd(UserAgent);

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

    private async Task<HttpResponseMessage> GetProductImageAsync()
    {
        var imageUrl = GetQueryParameter(this.Context.Request.RequestUri, "imageUrl");
        if (string.IsNullOrEmpty(imageUrl))
        {
            var badRequest = new HttpResponseMessage(HttpStatusCode.BadRequest);
            badRequest.Content = CreateJsonContent("{\"message\": \"imageUrl query parameter is required\"}");
            return badRequest;
        }

        this.Context.Request.RequestUri = new Uri(imageUrl);
        this.Context.Request.Headers.UserAgent.ParseAdd(UserAgent);

        return await this.Context.SendAsync(this.Context.Request, this.CancellationToken)
            .ConfigureAwait(false);
    }

    // System.Web.HttpUtility isn't in the custom-code namespace allowlist, so query strings are
    // parsed by hand here instead.
    private static string GetQueryParameter(Uri requestUri, string name)
    {
        var query = requestUri.Query.TrimStart('?');
        if (string.IsNullOrEmpty(query))
        {
            return null;
        }

        foreach (var pair in query.Split('&'))
        {
            var parts = pair.Split(new[] { '=' }, 2);
            if (parts.Length == 2 && parts[0] == name)
            {
                return Uri.UnescapeDataString(parts[1]);
            }
        }

        return null;
    }
}
