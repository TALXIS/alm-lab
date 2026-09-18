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

    // Captured from the UI when the item is opened, not assumed from the CMT seed data —
    // this is a real, shared Dataverse environment with no test fixture/teardown, and CP11's
    // own "try it live" walkthrough picks from these same records, so the absolute quantity
    // drifts across lab runs. Every assertion below is relative to this captured baseline.
    private int _startingQuantity;

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

        var quantityLocator = Page.GetByTestId("item-detail-qty");
        await quantityLocator.WaitForAsync(new LocatorWaitForOptions { Timeout = 15000 });
        var quantityText = await quantityLocator.InnerTextAsync();
        if (!int.TryParse(quantityText.Trim(), out _startingQuantity))
        {
            Assert.Fail($"Expected a numeric qty on hand but found '{quantityText}'.");
        }
    }

    [When("I pick a quantity of {string}")]
    public async Task WhenIPickAQuantityOf(string quantity)
    {
        await SubmitPickAsync(quantity);
    }

    [When("I try to pick more than the available quantity")]
    public async Task WhenITryToPickMoreThanTheAvailableQuantity()
    {
        await SubmitPickAsync((_startingQuantity + 1).ToString());
    }

    [Then("I should see an error that the requested quantity exceeds the available stock")]
    public async Task ThenIShouldSeeAnErrorThatTheRequestedQuantityExceedsTheAvailableStock()
    {
        var requested = _startingQuantity + 1;
        var message = $"Not enough product in stock. Available: {_startingQuantity}, requested: {requested}.";
        await Expect(Page.GetByText(message)).ToBeVisibleAsync(new() { Timeout = 15000 });
    }

    [Then("the quantity on hand should have decreased by {string}")]
    public async Task ThenTheQuantityOnHandShouldHaveDecreasedBy(string decrement)
    {
        var expected = (_startingQuantity - int.Parse(decrement)).ToString();
        await Expect(Page.GetByTestId("item-detail-qty")).ToHaveTextAsync(expected, new() { Timeout = 15000 });
    }

    // A "pick" in the UI is a New Transaction with type Outbound — fill the dialog the same
    // way a floor worker would: name, quantity, type, submit.
    private async Task SubmitPickAsync(string quantity)
    {
        await Page.GetByTestId("new-transaction-button").ClickAsync();
        var quantityInput = Page.Locator("#txQuantity");
        await quantityInput.WaitForAsync(new LocatorWaitForOptions { Timeout = 15000 });
        await Page.Locator("#txName").FillAsync($"BDD pick {DateTime.UtcNow:yyyyMMddHHmmss}");
        await quantityInput.FillAsync(quantity);
        await Page.GetByTestId("tx-type-trigger").ClickAsync();
        await Page.GetByRole(AriaRole.Option, new() { Name = "Outbound" }).ClickAsync();
        await Page.GetByTestId("submit-transaction").ClickAsync();
    }
}

