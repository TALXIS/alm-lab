using System.Text;

namespace Tests.UI.Authentication;

/// <summary>
/// Turns the persona in "Given I am logged in as '&lt;persona&gt;'" into a username, a password
/// and the file the resulting signed-in session is cached in.
/// </summary>
/// <remarks>
/// Scenarios name a role, not a UPN, so the same feature file runs against any tenant - the
/// mapping from role to account lives in .env, which is gitignored, and in CI in secrets.
/// </remarks>
public sealed record TestUser(string Username, string Password, string StorageStatePath, string? OtpSecret)
{
    public bool HasPassword => !string.IsNullOrEmpty(Password);

    /// <summary>An authenticator seed means MFA can be answered without a human present.</summary>
    public bool CanAnswerMfa => !string.IsNullOrEmpty(OtpSecret);
}

public static class TestCredentials
{
    /// <summary>"a warehouse manager" -> WAREHOUSE_MANAGER</summary>
    public static string PersonaKey(string persona)
    {
        var key = new StringBuilder();
        foreach (var c in persona.Trim().ToUpperInvariant())
        {
            key.Append(char.IsLetterOrDigit(c) ? c : '_');
        }

        var result = key.ToString().Trim('_');
        while (result.Contains("__")) result = result.Replace("__", "_");

        // An article in the sentence should not become part of the variable name: reading
        // "Given I am logged in as 'a warehouse manager'" and then looking for
        // TXC_USER_A_WAREHOUSE_MANAGER_USERNAME is a trap nobody guesses right first time.
        foreach (var article in new[] { "A_", "AN_", "THE_" })
        {
            if (result.StartsWith(article, StringComparison.Ordinal))
            {
                result = result[article.Length..];
                break;
            }
        }

        return result;
    }

    public static TestUser For(string persona)
    {
        DotEnv.Load();

        var key = PersonaKey(persona);

        // A persona written as a UPN still works - it is just its own username.
        var isUpn = persona.Contains('@');

        var username =
            Env($"TXC_USER_{key}_USERNAME") ??
            (isUpn ? persona.Trim() : null) ??
            Env("TXC_USER_USERNAME") ??
            Env("MS_AUTH_EMAIL");          // the name Microsoft's Playwright samples use

        var password =
            Env($"TXC_USER_{key}_PASSWORD") ??
            Env("TXC_USER_PASSWORD") ??
            Env("MS_USER_PASSWORD") ??
            string.Empty;

        if (string.IsNullOrWhiteSpace(username))
        {
            throw new InvalidOperationException(
                $"""
                 No account is configured for the persona '{persona}'.

                 Create src/Tests.UI/.env (gitignored, see .env.example) with:

                     TXC_USER_{key}_USERNAME=someone@yourtenant.onmicrosoft.com
                     TXC_USER_{key}_PASSWORD=...

                 or set TXC_USER_USERNAME / TXC_USER_PASSWORD to use one account for every
                 persona. Environment variables win over .env, so CI passes them as secrets.
                 """);
        }

        // TALXIS.TestKit calls this OtpToken; same idea, same reason - an MFA-protected test
        // account is otherwise unusable in a headless run.
        var otpSecret =
            Env($"TXC_USER_{key}_OTP_SECRET") ??
            Env("TXC_USER_OTP_SECRET") ??
            Env("MS_AUTH_OTP_SECRET");

        return new TestUser(username, password, StorageStatePathFor(username), otpSecret);
    }

    /// <summary>
    /// One cached session per account, so switching personas mid-run does not invalidate the
    /// other's cookies. Under .auth/, which is gitignored as a directory - a storage state is
    /// a live session, not a credential file, and leaks just as badly.
    /// </summary>
    public static string StorageStatePathFor(string username)
    {
        DotEnv.Load();

        var dir = Environment.GetEnvironmentVariable("TXC_AUTH_DIR")
                  ?? Path.Combine(DotEnv.AnchorDirectory, ".auth");

        Directory.CreateDirectory(dir);

        var safe = new StringBuilder();
        foreach (var c in username.ToLowerInvariant())
        {
            safe.Append(char.IsLetterOrDigit(c) ? c : '-');
        }

        return Path.Combine(dir, $"state-{safe}.json");
    }

    private static string? Env(string name)
    {
        var value = Environment.GetEnvironmentVariable(name);
        return string.IsNullOrWhiteSpace(value) ? null : value;
    }
}
