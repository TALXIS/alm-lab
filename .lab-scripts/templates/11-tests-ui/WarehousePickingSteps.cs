using Microsoft.Playwright;
using Reqnroll;
using Tests.UI.Support;
using static Microsoft.Playwright.Assertions;

namespace Tests.UI.StepDefinitions;

// Steps for the Warehouse Picking code app — a standalone Vite + React SPA, not a page
// embedded in the model-driven app shell, so it can't reuse Support/Bindings/NavigationSteps'
// "I open the '<app>' app" (that step navigates to main.aspx?appname=..., a model-driven-app
// -only URL). Same "custom UI needs custom bindings" split the frozen bindings' own docs
// describe for a genux dashboard page — the difference here is the whole app is outside the
// MDA shell, not just one page inside it, so even navigation is custom, not just assertions.
// Kept in StepDefinitions/, not Support/Bindings/, to signal "ours, not template-shipped."
[Binding]
public sealed class WarehousePickingSteps
{
    // The code app has no fixed deployed URL in this lab — attendees run it locally. Point at
    // the Vite dev server the CP11 "try it live" pause tells you to start with `npm run dev`.
    // Override with TXC_CODEAPP_URL once the app is actually deployed and you want to test
    // that URL instead.
    private const string DefaultCodeAppUrl = "http://localhost:5173";

    private readonly ScenarioContext _scenarioContext;
    private IPage Page => (IPage)_scenarioContext[Hooks.PageKey];

    public WarehousePickingSteps(ScenarioContext scenarioContext)
    {
        _scenarioContext = scenarioContext;
    }

    [Given("I open the warehouse picking app")]
    public async Task GivenIOpenTheWarehousePickingApp()
    {
        var baseUrl = Environment.GetEnvironmentVariable("TXC_CODEAPP_URL") ?? DefaultCodeAppUrl;
        await Page.GotoAsync(baseUrl);
        await Page.GetByTestId("warehouse-item-row").First.WaitForAsync(
            new LocatorWaitForOptions { Timeout = 15000 });
    }

    [Given("I open the {string} item")]
    public async Task GivenIOpenTheItem(string itemName)
    {
        var row = Page.GetByTestId("warehouse-item-row").Filter(new() { HasText = itemName });
        await row.WaitForAsync(new LocatorWaitForOptions { Timeout = 15000 });
        await row.GetByRole(AriaRole.Link).ClickAsync();
        await Page.GetByTestId("pick-button").WaitForAsync(new LocatorWaitForOptions { Timeout = 15000 });
    }

    [When("I pick a quantity of {string}")]
    public async Task WhenIPickAQuantityOf(string quantity)
    {
        await Page.GetByTestId("pick-button").ClickAsync();
        var quantityInput = Page.Locator("#tx-quantity");
        await quantityInput.WaitForAsync(new LocatorWaitForOptions { Timeout = 15000 });
        await quantityInput.FillAsync(quantity);
        await Page.GetByTestId("submit-transaction").ClickAsync();
    }

    [Then("I should see the error {string}")]
    public async Task ThenIShouldSeeTheError(string message)
    {
        await Expect(Page.GetByText(message)).ToBeVisibleAsync(new() { Timeout = 15000 });
    }

    [Then("the quantity on hand should read {string}")]
    public async Task ThenTheQuantityOnHandShouldRead(string expectedQuantity)
    {
        await Expect(Page.GetByTestId("item-detail-qty")).ToHaveTextAsync(expectedQuantity, new() { Timeout = 15000 });
    }
}
