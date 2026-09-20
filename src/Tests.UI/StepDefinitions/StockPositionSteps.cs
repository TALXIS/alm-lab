using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Playwright;
using Reqnroll;
using Tests.UI.Support;

namespace Tests.UI.StepDefinitions;

/// <summary>
/// Job J4 — checking one item's stock position against its own reorder point.
/// Implements Features/CheckStockPosition.feature.
/// </summary>
/// <remarks>
/// Kept out of Support/Bindings/ deliberately: those are the frozen model-driven vocabulary,
/// and none of them can express "an item whose stock is below its reorder point" — that is a
/// sentence about this domain, not about Dataverse.
///
/// The scenarios name no item. They cannot: the reorder point is a per-item setting a manager
/// changes, this runs against a shared environment with no fixture or teardown, and CP11's "try
/// it live" walkthrough moves the seeded quantities around. So the binding finds an item that
/// satisfies the precondition and remembers what it found, and the assertions are relative to
/// that. If a run cannot find one, it says which precondition was unmet rather than failing on
/// a stale record.
/// </remarks>
[Binding]
public sealed class StockPositionSteps
{
    private const string ItemEntity = "almlab_warehouseitem";
    private const string CheckStockCommand = "Check Stock Levels";

    /// <summary>How long to look for a command before trying the overflow menu instead.</summary>
    private const int OverflowProbeMs = 5000;

    private const string SelectedItemKey = "StockPosition.Item";
    private const string DialogTextKey = "StockPosition.DialogText";

    private readonly ScenarioContext _scenarioContext;
    private IPage Page => (IPage)_scenarioContext[Hooks.PageKey];

    public StockPositionSteps(ScenarioContext scenarioContext)
    {
        _scenarioContext = scenarioContext;
    }

    private sealed record StockItem(string Id, string Name, int Quantity, int ReorderPoint);

    [Given(@"^I have opened an item whose stock is (below|above) its reorder point$")]
    public async Task GivenIHaveOpenedAnItemWhoseStockIs(string position)
    {
        var below = position == "below";

        await OpenAppAsync();
        var item = await FindItemAsync(below);

        var baseUrl = TestConfiguration.EnvironmentUrl.TrimEnd('/');
        await Page.GotoAsync(
            $"{baseUrl}/main.aspx?appname={Uri.EscapeDataString(TestConfiguration.AppName)}" +
            $"&pagetype=entityrecord&etn={ItemEntity}&id={item.Id}");

        await ModelDrivenAppHelpers.WaitForFormReadyAsync(Page);

        _scenarioContext[SelectedItemKey] = item;
    }

    [When("I check its stock level")]
    public async Task WhenICheckItsStockLevel()
    {
        await ClickCommandAsync(CheckStockCommand);

        // The command opens an Xrm alert dialog. Read it once and keep the text: the Thens below
        // each assert one part of the same message, and re-reading a dialog someone might have
        // dismissed is how a passing assertion turns into a flake.
        var dialog = Page.Locator("[role='dialog']:visible, [data-id='alertdialog']:visible").First;

        await dialog.WaitForAsync(new LocatorWaitForOptions
        {
            State = WaitForSelectorState.Visible,
            Timeout = TestConfiguration.Timeout
        });

        _scenarioContext[DialogTextKey] = (await dialog.InnerTextAsync()).Trim();
    }

    [Then("I am told how many are on hand")]
    public void ThenIAmToldHowManyAreOnHand()
    {
        var item = SelectedItem;
        var text = DialogText;

        StringAssert.Contains(
            text, item.Quantity.ToString(),
            $"The stock check for '{item.Name}' should state the {item.Quantity} on hand. It said: {text}");
    }

    [Then(@"^I am told it is (below|above) its reorder point$")]
    public void ThenIAmToldItIs(string position)
    {
        var item = SelectedItem;
        var text = DialogText;

        // The wording comes from RibbonActions.checkStockLevels in Scripts.UI. Asserting on the
        // phrase rather than the icon keeps this readable and survives the icon changing.
        var expected = position == "below" ? "below reorder point" : "above reorder point";

        Assert.IsTrue(
            text.Contains(expected, StringComparison.OrdinalIgnoreCase),
            $"""
             '{item.Name}' holds {item.Quantity} against a reorder point of {item.ReorderPoint},
             so the stock check should have said it is {position} it.
             It said: {text}
             """);
    }

    private StockItem SelectedItem => (StockItem)_scenarioContext[SelectedItemKey];

    private string DialogText => (string)_scenarioContext[DialogTextKey];

    /// <summary>
    /// Loads the app itself, which is what puts Xrm - and therefore Xrm.WebApi - on the page.
    /// The persona step only signs in; it does not know which app a scenario is about.
    /// </summary>
    private async Task OpenAppAsync()
    {
        var baseUrl = TestConfiguration.EnvironmentUrl.TrimEnd('/');
        await Page.GotoAsync($"{baseUrl}/main.aspx?appname={Uri.EscapeDataString(TestConfiguration.AppName)}");

        await Page.WaitForFunctionAsync(
            "() => typeof window.Xrm?.WebApi?.retrieveMultipleRecords === 'function'",
            null,
            new PageWaitForFunctionOptions { Timeout = TestConfiguration.Timeout });
    }

    private async Task<StockItem> FindItemAsync(bool below)
    {
        // OData cannot compare two columns to each other, so the comparison happens here rather
        // than in $filter. Items with no reorder point are skipped on purpose: the grid treats a
        // missing one as 10 and the ribbon script treats it as 0, so an item without one would
        // make this test depend on which of those two disagreeing defaults it happened to hit.
        var match = await Page.EvaluateAsync<JsonElement?>(
            """
            async ({ below }) => {
              const response = await window.Xrm.WebApi.retrieveMultipleRecords(
                'almlab_warehouseitem',
                '?$select=almlab_warehouseitemid,almlab_name,almlab_availablequantity,almlab_reorderpoint&$top=250');

              const candidate = response.entities.find(row =>
                typeof row.almlab_availablequantity === 'number' &&
                typeof row.almlab_reorderpoint === 'number' &&
                (below
                  ? row.almlab_availablequantity <= row.almlab_reorderpoint
                  : row.almlab_availablequantity > row.almlab_reorderpoint));

              return candidate
                ? {
                    id: candidate.almlab_warehouseitemid,
                    name: candidate.almlab_name,
                    quantity: candidate.almlab_availablequantity,
                    reorderPoint: candidate.almlab_reorderpoint
                  }
                : null;
            }
            """,
            new { below });

        if (match is null || match.Value.ValueKind == JsonValueKind.Null)
        {
            Assert.Fail(
                $"""
                 No warehouse item currently holds a quantity {(below ? "at or below" : "above")} its
                 reorder point, so this scenario has nothing to check.

                 Both an item that needs restocking and one that does not have to exist in
                 {TestConfiguration.EnvironmentUrl} for J4 to be testable. The seeded data provides
                 both; if it no longer does, someone has moved the quantities.
                 """);
        }

        var element = match.Value;
        return new StockItem(
            element.GetProperty("id").GetString()!,
            element.GetProperty("name").GetString() ?? "(unnamed)",
            element.GetProperty("quantity").GetInt32(),
            element.GetProperty("reorderPoint").GetInt32());
    }

    /// <summary>
    /// The form's own command bar, told apart from the other two on the page.
    /// </summary>
    /// <remarks>
    /// A record form with a subgrid renders three <c>ul[data-id="CommandBar"]</c> elements: the
    /// app header (Search, New, Advanced find...), the form's, and the subgrid's. Taking the
    /// first is how an earlier version of this opened the wrong overflow menu. The form's
    /// commands are the ones whose data-id carries <c>|Form|</c>; a subgrid's carry
    /// <c>|SubGridStandard|</c> and the header's are named launchers.
    /// </remarks>
    private ILocator FormCommandBar =>
        Page.Locator("ul[data-id='CommandBar']")
            .Filter(new LocatorFilterOptions { Has = Page.Locator("button[data-id*='|Form|']") })
            .First;

    /// <summary>
    /// Matches a command on its visible text, anchored.
    /// </summary>
    /// <remarks>
    /// Not on aria-label: the live markup puts the tooltip in it after two newlines — Save's is
    /// <c>"Save (CTRL+S)\n\nSave this Warehouse Item."</c> — so an equality match on the label
    /// never fires, and a substring match on "Save" also hits "Save &amp; Close". The visible
    /// text is the clean label, and anchoring it keeps the two apart.
    /// </remarks>
    private ILocator CommandLocator(string commandLabel) =>
        FormCommandBar
            .Locator("button[role='menuitem']")
            .Filter(new LocatorFilterOptions { HasTextRegex = new Regex($"^{Regex.Escape(commandLabel)}$") })
            .First;

    private async Task ClickCommandAsync(string commandLabel)
    {
        // The ribbon renders after the form's data binds, so WaitForFormReadyAsync returning is
        // not enough on its own — it reports Xrm attributes, not chrome. Waiting for the form's
        // command bar to appear is the signal that the rest has painted. Checking visibility at a
        // point in time instead of waiting is what made an earlier version fail in six seconds
        // against a command that was about to appear.
        await FormCommandBar.WaitForAsync(new LocatorWaitForOptions
        {
            State = WaitForSelectorState.Visible,
            Timeout = TestConfiguration.Timeout
        });

        var command = CommandLocator(commandLabel);

        if (await WaitForVisibleAsync(command, OverflowProbeMs))
        {
            await command.ClickAsync();
            return;
        }

        // A narrow window pushes later commands into the overflow menu.
        var overflow = FormCommandBar.Locator("button[data-id='OverflowButton']").First;

        if (await WaitForVisibleAsync(overflow, OverflowProbeMs))
        {
            await overflow.ClickAsync();

            var overflowCommand = Page
                .Locator("[role='menu'] button, [role='menu'] [role='menuitem']")
                .Filter(new LocatorFilterOptions { HasTextRegex = new Regex($"^{Regex.Escape(commandLabel)}$") })
                .First;

            if (await WaitForVisibleAsync(overflowCommand, OverflowProbeMs))
            {
                await overflowCommand.ClickAsync();
                return;
            }
        }

        Assert.Fail(
            $"""
             The command '{commandLabel}' is not on the form's command bar, on screen or in its
             overflow. What is there: {await DescribeCommandsAsync()}
             """);
    }

    private static async Task<bool> WaitForVisibleAsync(ILocator locator, int timeoutMs)
    {
        try
        {
            await locator.WaitForAsync(new LocatorWaitForOptions
            {
                State = WaitForSelectorState.Visible,
                Timeout = timeoutMs
            });
            return true;
        }
        catch (TimeoutException)
        {
            return false;
        }
    }

    /// <summary>Lists the commands actually on screen, so a rename is diagnosed from one run.</summary>
    private async Task<string> DescribeCommandsAsync()
    {
        var names = await Page.EvaluateAsync<string[]>(
            """
            () => Array.from(document.querySelectorAll('button, [role="menuitem"], [role="button"]'))
              .filter(element => {
                // Not offsetParent: it is null for position:fixed chrome, which reported
                // "nothing visible" on a page that plainly had a command bar on it.
                const box = element.getBoundingClientRect();
                return box.width > 0 && box.height > 0;
              })
              .map(element => (element.getAttribute('aria-label') || element.textContent || '').trim())
              .filter(name => name.length > 0)
            """);

        return names.Length == 0 ? "(nothing visible)" : string.Join(" · ", names.Distinct());
    }
}
