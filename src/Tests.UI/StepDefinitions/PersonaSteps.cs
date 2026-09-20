using Reqnroll;
using Tests.UI.Authentication;

namespace Tests.UI.StepDefinitions;

/// <summary>
/// "Given I am a warehouse manager" - the phrasing the design documents use.
/// </summary>
/// <remarks>
/// design/features/*.feature name their actors the way design/personas.md does, as a role in a
/// sentence rather than a quoted argument. One regex binding covers every persona in that cast,
/// so a new persona needs a .env entry and nothing else.
///
/// It resolves to exactly the same place as the frozen "I am logged in as '&lt;persona&gt;'"
/// step - TestCredentials turns "a warehouse manager" into TXC_USER_WAREHOUSE_MANAGER_* either
/// way - so the two phrasings cannot drift into two different accounts.
/// </remarks>
[Binding]
public sealed class PersonaSteps
{
    private readonly ScenarioContext _scenarioContext;

    public PersonaSteps(ScenarioContext scenarioContext)
    {
        _scenarioContext = scenarioContext;
    }

    // Anchored, and the role must be lower-case words only, so this cannot swallow
    // "I am logged in as '...'" or anything else starting "I am".
    [Given(@"^I am (an? [a-z][a-z ]*)$")]
    public async Task GivenIAm(string persona)
    {
        _scenarioContext["Profile"] = persona;
        await SignIn.EnsureSignedInAsync(_scenarioContext, persona);
    }
}
