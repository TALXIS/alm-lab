using Microsoft.Playwright;
using Reqnroll;
using Tests.UI.Support;

namespace Tests.UI.Authentication;

/// <summary>
/// Makes "Given I am logged in as '&lt;persona&gt;'" actually sign in.
///
/// First run for an account: drives the Microsoft sign-in page with credentials from .env and
/// caches the resulting session under .auth/. Every run after that reuses the cached session,
/// so the scenarios are headless and offline of the login page. When the cache is missing or
/// expired the sign-in simply happens again - there is no separate "capture auth" command to
/// remember to run first, which is the part that always rots.
/// </summary>
public static class SignIn
{
    private const string EmailSelector = "input[type='email'], input[name='loginfmt']";
    private const string PasswordSelector = "input[type='password'], input[name='passwd']";
    private const string SubmitSelector = "input[type='submit'], button[type='submit']";

    // Entra moves this markup between templates, so cast a wide net rather than pin one id.
    // ":visible" is load-bearing. Without it .First latches onto whichever of these exists in
    // the DOM first - usually an empty placeholder that never becomes visible - and the wait
    // burns its whole budget while the real message sits on screen.
    /// <summary>How long a visible error waits for an in-flight redirect to prove it wrong.</summary>
    private const int RedirectGraceMs = 5000;

    private const string ErrorSelector =
        "#passwordError:visible, #usernameError:visible, [role='alert']:visible, " +
        ".alert-error:visible, [aria-live='assertive']:visible";

    public static async Task EnsureSignedInAsync(ScenarioContext scenarioContext, string persona)
    {
        var user = TestCredentials.For(persona);

        // An explicitly configured StorageStatePath is someone saying "use this session, I
        // captured it myself" - Hooks already applied it, so don't second-guess them.
        var explicitState = !string.IsNullOrWhiteSpace(TestConfiguration.StorageStatePath);
        if (!explicitState && File.Exists(user.StorageStatePath))
        {
            await ReplaceContextAsync(scenarioContext, user.StorageStatePath);
        }

        var page = (IPage)scenarioContext[Hooks.PageKey];
        var environmentUrl = TestConfiguration.EnvironmentUrl.TrimEnd('/');

        await page.GotoAsync(environmentUrl, new PageGotoOptions
        {
            WaitUntil = WaitUntilState.DOMContentLoaded
        });

        if (!await IsSignInPageAsync(page))
        {
            return; // cached session still good
        }

        if (!user.HasPassword)
        {
            throw new InvalidOperationException(
                $"""
                 '{persona}' resolved to {user.Username}, but there is no password for it and no
                 usable cached session at {user.StorageStatePath}.

                 Put TXC_USER_{TestCredentials.PersonaKey(persona)}_PASSWORD (or TXC_USER_PASSWORD)
                 in src/Tests.UI/.env, or capture a session by hand and point
                 TXC_STORAGE_STATE_PATH at it.
                 """);
        }

        await SignInAsync(page, user, environmentUrl);

        var context = (IBrowserContext)scenarioContext[Hooks.BrowserContextKey];
        await context.StorageStateAsync(new BrowserContextStorageStateOptions
        {
            Path = user.StorageStatePath
        });
    }

    private static async Task<bool> IsSignInPageAsync(IPage page)
    {
        // Don't test on the URL: an environment can federate to somewhere other than
        // login.microsoftonline.com, and a tenant with an active session redirects straight
        // back. The email field is the thing that actually decides whether we must act.
        var host = new Uri(page.Url).Host;
        if (host.EndsWith(".dynamics.com", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        try
        {
            await page.Locator(EmailSelector).First.WaitForAsync(new LocatorWaitForOptions
            {
                State = WaitForSelectorState.Visible,
                Timeout = 15000
            });
            return true;
        }
        catch (TimeoutException)
        {
            return false;
        }
    }

    private static async Task SignInAsync(IPage page, TestUser user, string environmentUrl)
    {
        var email = page.Locator(EmailSelector).First;
        await email.FillAsync(user.Username);
        await page.Locator(SubmitSelector).First.ClickAsync();

        var password = page.Locator(PasswordSelector).First;
        try
        {
            await password.WaitForAsync(new LocatorWaitForOptions
            {
                State = WaitForSelectorState.Visible,
                Timeout = TestConfiguration.Timeout
            });
        }
        catch (TimeoutException)
        {
            // A wrong username never reaches a password box. Report what the sign-in page
            // actually said instead of "locator timed out", which reads like a test bug.
            var reason = await FirstVisibleTextAsync(page, ErrorSelector);
            throw new InvalidOperationException(
                $"""
                 Sign-in stopped before the password step for {user.Username}.
                 {(reason is null ? "No password field appeared." : $"The sign-in page said: {reason}")}
                 Check the username in src/Tests.UI/.env. Current page: {page.Url}
                 """);
        }

        await password.FillAsync(user.Password);
        await page.Locator(SubmitSelector).First.ClickAsync();

        await HandleOneTimeCodeAsync(page, user);
        await HandleStaySignedInAsync(page);
        await WaitForEnvironmentAsync(page, environmentUrl, user);
    }

    /// <summary>
    /// Types the six digits when Entra asks for a verification code and we hold the seed.
    /// Anything else MFA can ask for - an Authenticator push, a phone call - still needs a human,
    /// and WaitForEnvironmentAsync says so.
    /// </summary>
    private static async Task HandleOneTimeCodeAsync(IPage page, TestUser user)
    {
        if (!user.CanAnswerMfa) return;

        var code = page.Locator("input[name='otc'], input#idTxtBx_SAOTCC_OTC").First;

        try
        {
            await code.WaitForAsync(new LocatorWaitForOptions
            {
                State = WaitForSelectorState.Visible,
                Timeout = 15000
            });
        }
        catch (TimeoutException)
        {
            return; // no code was asked for
        }

        // Generate as late as possible: the codes roll every 30 seconds and the password step
        // above may have taken a while.
        await code.FillAsync(Totp.Generate(user.OtpSecret!));
        await page.Locator(SubmitSelector).First.ClickAsync();
    }

    /// <summary>
    /// "Stay signed in?" - answering Yes is what makes the cookies persistent, and a persisted
    /// cookie is the entire point of caching the session.
    /// </summary>
    private static async Task HandleStaySignedInAsync(IPage page)
    {
        try
        {
            var yes = page.Locator("#idSIButton9, input[type='submit'][value='Yes']").First;
            await yes.WaitForAsync(new LocatorWaitForOptions
            {
                State = WaitForSelectorState.Visible,
                Timeout = 10000
            });
            await yes.ClickAsync();
        }
        catch (TimeoutException)
        {
            // Not every tenant shows it, and a tenant that skips it is not an error.
        }
    }

    private static async Task WaitForEnvironmentAsync(IPage page, string environmentUrl, TestUser user)
    {
        var host = new Uri(environmentUrl).Host;

        // Headed runs get five minutes so a human can finish MFA; headless runs get the normal
        // timeout, because there is nobody there to approve anything.
        var budget = TestConfiguration.Headless ? TestConfiguration.Timeout : 300_000;

        // Race the redirect against the sign-in page complaining. Without this, a wrong password
        // costs the whole budget - five minutes in a headed run - before saying anything, and the
        // answer was on screen two seconds in. Whichever resolves first decides.
        var arrived = Swallow(page.WaitForURLAsync(
            url => new Uri(url).Host.Equals(host, StringComparison.OrdinalIgnoreCase),
            new PageWaitForURLOptions { Timeout = budget }));

        var complained = Swallow(page.Locator(ErrorSelector).First.WaitForAsync(new LocatorWaitForOptions
        {
            State = WaitForSelectorState.Visible,
            Timeout = budget
        }));

        var first = await Task.WhenAny(arrived, complained);

        if (first == arrived)
        {
            if (await arrived) return;
        }
        else
        {
            // The error won, but it may only have won because the redirect is still in flight -
            // Entra flashes a "we're signing you in" alert on the way through. Give the redirect
            // a short grace period. Awaiting `arrived` outright here would block for the entire
            // budget, which is the whole thing this race exists to avoid.
            await Task.WhenAny(arrived, Task.Delay(RedirectGraceMs));

            if (arrived.IsCompletedSuccessfully && arrived.Result) return;
        }

        throw new InvalidOperationException(await DescribeFailureAsync(page, user), null);
    }

    private static async Task<string> DescribeFailureAsync(IPage page, TestUser user)
    {
        var error = await FirstVisibleTextAsync(page, ErrorSelector);

        if (await LooksLikeMfaAsync(page))
        {
            var seedHint = user.CanAnswerMfa
                ? "An authenticator seed is configured, so this prompt is asking for something a seed cannot answer - a push approval or a phone call rather than a typed code."
                : "Set TXC_USER_OTP_SECRET (or TXC_USER_<PERSONA>_OTP_SECRET) to the account's authenticator seed and the six digits are generated for you on every run.";

            return $"""
                    Sign-in as {user.Username} stopped at a multi-factor prompt{(TestConfiguration.Headless ? " and the run is headless, so nobody can approve it" : "")}.

                    {seedHint}

                    Otherwise run it once with a browser you can see - approve the prompt and the
                    session is cached in .auth/ for every headless run afterwards:

                        TXC_HEADLESS=false dotnet test src/Tests.UI --filter "TestCategory=auth"

                    Current page: {page.Url}
                    """;
        }

        return $"""
                Sign-in as {user.Username} did not reach {TestConfiguration.EnvironmentUrl}.
                {(error is null ? "" : $"The page said: {error}")}
                Current page: {page.Url}
                """;
    }

    private static async Task<bool> LooksLikeMfaAsync(IPage page)
    {
        foreach (var selector in new[]
                 {
                     "#idDiv_SAOTCS_Proofs", "input[name='otc']", "#idRichContext_DisplaySign",
                     "text=Approve sign in request", "text=Verify your identity"
                 })
        {
            if (await page.Locator(selector).First.IsVisibleAsync()) return true;
        }

        return false;
    }

    /// <summary>
    /// Entra's markup moves around between templates, and a selector often matches a hidden
    /// placeholder before the real one, so take every match rather than .First and return the
    /// first that is both visible and says something.
    /// </summary>
    private static async Task<string?> FirstVisibleTextAsync(IPage page, params string[] selectors)
    {
        foreach (var selector in selectors)
        {
            foreach (var locator in await page.Locator(selector).AllAsync())
            {
                if (!await locator.IsVisibleAsync()) continue;

                var text = (await locator.InnerTextAsync()).Trim();
                if (text.Length > 0) return text;
            }
        }

        return null;
    }

    /// <summary>Runs a wait to completion, reporting success as a bool instead of throwing.</summary>
    private static async Task<bool> Swallow(Task task)
    {
        try
        {
            await task;
            return true;
        }
        catch (TimeoutException)
        {
            return false;
        }
    }

    /// <summary>
    /// Storage state can only be applied when a context is created, and the context already
    /// exists by the time a Given runs. Swapping it here rather than in a hook keeps the
    /// decision - which account, therefore which session file - inside the step that states it.
    /// Nothing has happened in the page yet, so there is nothing to lose.
    /// </summary>
    private static async Task ReplaceContextAsync(ScenarioContext scenarioContext, string storageStatePath)
    {
        var current = (IBrowserContext)scenarioContext[Hooks.BrowserContextKey];
        var browser = current.Browser
                      ?? throw new InvalidOperationException("The browser context is not attached to a browser.");

        var replacement = await browser.NewContextAsync(new BrowserNewContextOptions
        {
            ViewportSize = null,
            StorageStatePath = storageStatePath
        });

        if (TestConfiguration.TracingEnabled)
        {
            await replacement.Tracing.StartAsync(new TracingStartOptions
            {
                Screenshots = true,
                Snapshots = true,
                Sources = true
            });
        }

        await current.CloseAsync();

        var page = await replacement.NewPageAsync();
        page.SetDefaultTimeout(TestConfiguration.Timeout);

        scenarioContext[Hooks.BrowserContextKey] = replacement;
        scenarioContext[Hooks.PageKey] = page;
    }
}
