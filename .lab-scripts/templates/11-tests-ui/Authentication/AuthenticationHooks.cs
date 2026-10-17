using Reqnroll;

namespace Tests.UI.Authentication;

[Binding]
public sealed class AuthenticationHooks
{
    /// <summary>
    /// Order 0 so .env reaches the process environment before anything reads
    /// <see cref="Support.TestConfiguration"/> - its configuration root chains
    /// AddEnvironmentVariables and is built once, on first touch.
    /// </summary>
    [BeforeTestRun(Order = 0)]
    public static void LoadDotEnv() => DotEnv.Load();
}
