using Tests.UI.Authentication;

namespace Tests.UI.Tests;

[TestClass]
public sealed class TestCredentialsTests
{
    [TestMethod]
    [DataRow("a warehouse manager", "WAREHOUSE_MANAGER")]
    [DataRow("a warehouse floor worker", "WAREHOUSE_FLOOR_WORKER")]
    [DataRow("an administrator", "ADMINISTRATOR")]
    [DataRow("the dispatcher", "DISPATCHER")]
    [DataRow("Warehouse Manager", "WAREHOUSE_MANAGER")]
    [DataRow("  a  warehouse   manager  ", "WAREHOUSE_MANAGER")]
    [DataRow("someone@contoso.onmicrosoft.com", "SOMEONE_CONTOSO_ONMICROSOFT_COM")]
    public void PersonaKey_drops_articles_and_normalises_separators(string persona, string expected) =>
        Assert.AreEqual(expected, TestCredentials.PersonaKey(persona));

    [TestMethod]
    public void PersonaKey_does_not_strip_an_article_that_is_part_of_a_word() =>
        // "AN_" must not eat the start of "ANALYST"
        Assert.AreEqual("ANALYST", TestCredentials.PersonaKey("analyst"));

    [TestMethod]
    public void For_prefers_the_persona_specific_account_over_the_shared_one()
    {
        using var _ = new EnvironmentScope(
            ("TXC_USER_USERNAME", "shared@contoso.com"),
            ("TXC_USER_PASSWORD", "shared-secret"),
            ("TXC_USER_WAREHOUSE_MANAGER_USERNAME", "manager@contoso.com"),
            ("TXC_USER_WAREHOUSE_MANAGER_PASSWORD", "manager-secret"));

        var user = TestCredentials.For("a warehouse manager");

        Assert.AreEqual("manager@contoso.com", user.Username);
        Assert.AreEqual("manager-secret", user.Password);
    }

    [TestMethod]
    public void For_falls_back_to_the_shared_account()
    {
        using var _ = new EnvironmentScope(
            ("TXC_USER_USERNAME", "shared@contoso.com"),
            ("TXC_USER_PASSWORD", "shared-secret"),
            ("TXC_USER_WAREHOUSE_MANAGER_USERNAME", null),
            ("TXC_USER_WAREHOUSE_MANAGER_PASSWORD", null));

        var user = TestCredentials.For("a warehouse manager");

        Assert.AreEqual("shared@contoso.com", user.Username);
        Assert.AreEqual("shared-secret", user.Password);
    }

    [TestMethod]
    public void For_treats_a_persona_written_as_a_upn_as_the_account()
    {
        using var _ = new EnvironmentScope(
            ("TXC_USER_USERNAME", null),
            ("MS_AUTH_EMAIL", null),
            ("TXC_USER_PASSWORD", "secret"));

        var user = TestCredentials.For("someone@contoso.onmicrosoft.com");

        Assert.AreEqual("someone@contoso.onmicrosoft.com", user.Username);
    }

    [TestMethod]
    public void For_explains_itself_when_nothing_is_configured()
    {
        using var _ = new EnvironmentScope(
            ("TXC_USER_USERNAME", null),
            ("TXC_USER_PASSWORD", null),
            ("MS_AUTH_EMAIL", null),
            ("MS_USER_PASSWORD", null),
            ("TXC_USER_DISPATCHER_USERNAME", null));

        var error = Assert.ThrowsExactly<InvalidOperationException>(
            () => TestCredentials.For("a dispatcher"));

        // The message has to name the variable the reader must create, not just complain.
        StringAssert.Contains(error.Message, "TXC_USER_DISPATCHER_USERNAME");
    }

    [TestMethod]
    public void StorageStatePathFor_is_stable_and_one_file_per_account()
    {
        using var _ = new EnvironmentScope(("TXC_AUTH_DIR", Path.Combine(Path.GetTempPath(), "alm-lab-auth-tests")));

        var first = TestCredentials.StorageStatePathFor("Someone@Contoso.com");
        var again = TestCredentials.StorageStatePathFor("someone@contoso.com");
        var other = TestCredentials.StorageStatePathFor("other@contoso.com");

        Assert.AreEqual(first, again, "The same account must reuse the same cached session.");
        Assert.AreNotEqual(first, other, "Two accounts must not share one cached session.");
        StringAssert.EndsWith(first, "state-someone-contoso-com.json");
    }

    /// <summary>Sets environment variables for the duration of a test and puts them back.</summary>
    private sealed class EnvironmentScope : IDisposable
    {
        private readonly (string Name, string? Original)[] _saved;

        public EnvironmentScope(params (string Name, string? Value)[] values)
        {
            _saved = values
                .Select(v => (v.Name, Environment.GetEnvironmentVariable(v.Name)))
                .ToArray();

            foreach (var (name, value) in values)
            {
                Environment.SetEnvironmentVariable(name, value);
            }
        }

        public void Dispose()
        {
            foreach (var (name, original) in _saved)
            {
                Environment.SetEnvironmentVariable(name, original);
            }
        }
    }
}
