using Microsoft.Playwright;
using Reqnroll;

namespace Tests.UI.Support.Bindings;

[Binding]
public sealed class ViewSteps
{
    private readonly ScenarioContext _scenarioContext;
    private IPage Page => (IPage)_scenarioContext[Hooks.PageKey];

    public ViewSteps(ScenarioContext scenarioContext)
    {
        _scenarioContext = scenarioContext;
    }

    [When("I switch to the {string} view")]
    public async Task WhenISwitchToTheView(string viewName)
    {
        var viewSelector = Page.Locator("[data-id*='ViewSelector'], button[data-id*='ViewSelector']").First;
        await viewSelector.ClickAsync();

        await Page.GetByRole(AriaRole.Option, new PageGetByRoleOptions { Name = viewName }).ClickAsync();
    }

    [When("I open the record at row {int}")]
    public async Task WhenIOpenTheRecordAtRow(int index)
    {
        var row = GetGridRow(index);
        var link = row.Locator("[role='gridcell'] a").First;

        if (await link.CountAsync() > 0)
        {
            await link.ClickAsync();
        }
        else
        {
            await row.DblClickAsync();
        }

        await ModelDrivenAppHelpers.WaitForFormReadyAsync(Page);
    }

    [When("I select the record at row {int}")]
    public async Task WhenISelectTheRecordAtRow(int index)
    {
        var checkbox = GetGridRow(index).Locator("[role='gridcell'] input[type='checkbox']").First;
        await checkbox.CheckAsync(new LocatorCheckOptions { Force = true });
    }

    [When("I search for {string} in the grid")]
    public async Task WhenISearchForInTheGrid(string text)
    {
        var quickFind = Page.Locator("input[data-id='quickFind-text-editor'], input[aria-label*='Filter by keyword']").First;
        await quickFind.FillAsync(text);
        await quickFind.PressAsync("Enter");
    }

    [When("I sort the grid by {string}")]
    public async Task WhenISortTheGridBy(string columnLabel)
    {
        await Page.GetByRole(AriaRole.Columnheader, new PageGetByRoleOptions { Name = columnLabel }).ClickAsync();
    }

    // Lab deviation from the frozen binding: upstream this waits for the view selector to be
    // visible and then reads it once. The selector is already visible while the previous view is
    // still on screen, so a scenario that moves between two views reads the old name and fails
    // with "expected Active Warehouse Locations, but found Active Warehouse Items". Waiting for
    // the text itself polls until it changes. The step text is unchanged.
    [Then("I should see the {string} view")]
    public async Task ThenIShouldSeeTheView(string viewName)
    {
        var viewSelector = Page.Locator("[data-id*='ViewSelector'], button[data-id*='ViewSelector']").First;

        await Assertions.Expect(viewSelector).ToContainTextAsync(
            viewName,
            new LocatorAssertionsToContainTextOptions
            {
                IgnoreCase = true,
                Timeout = TestConfiguration.Timeout
            });
    }

    [Then("the grid should contain {int} records")]
    public async Task ThenTheGridShouldContainRecords(int count)
    {
        var actualCount = await Page.Locator("[role='row'][row-index]").CountAsync();
        Assert.AreEqual(count, actualCount, "The grid row count did not match.");
    }

    [Then("the grid should contain a record with {string} equal to {string}")]
    public async Task ThenTheGridShouldContainARecordWithEqualTo(string columnLabel, string value)
    {
        var columnHeader = Page.GetByRole(AriaRole.Columnheader, new PageGetByRoleOptions { Name = columnLabel });
        var columnId = await columnHeader.GetAttributeAsync("data-id") ?? await columnHeader.GetAttributeAsync("col-id");

        ILocator matchingCells;
        if (!string.IsNullOrWhiteSpace(columnId))
        {
            matchingCells = Page.Locator($"[role='row'][row-index] [role='gridcell'][col-id='{columnId}'], [role='row'][row-index] [role='gridcell'][data-id='{columnId}']")
                .Filter(new LocatorFilterOptions { HasText = value });
        }
        else
        {
            matchingCells = Page.Locator("[role='row'][row-index] [role='gridcell']").Filter(new LocatorFilterOptions { HasText = value });
        }

        Assert.IsTrue(await matchingCells.CountAsync() > 0, $"No grid record found with '{columnLabel}' equal to '{value}'.");
    }

    private ILocator GetGridRow(int index) => Page.Locator($"[role='row'][row-index='{index}']").First;
}
