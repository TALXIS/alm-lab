namespace Tests.UI.Authentication;

/// <summary>
/// Minimal .env reader. Values land in the process environment, so they reach both
/// <see cref="Support.TestConfiguration"/> (which already chains AddEnvironmentVariables) and
/// <see cref="TestCredentials"/> without either of them knowing this file exists.
/// </summary>
/// <remarks>
/// Deliberately not a NuGet package: this is ~40 lines, and a test project that holds a
/// password should have as little third-party code around that password as possible.
/// A variable already set in the real environment always wins, so CI secrets are never
/// shadowed by a stale .env someone forgot to delete.
/// </remarks>
public static class DotEnv
{
    private static readonly object Gate = new();
    private static bool _loaded;

    /// <summary>The directory the .env was found in, or the project directory. Anchors .auth/.</summary>
    public static string AnchorDirectory { get; private set; } = AppContext.BaseDirectory;

    public static void Load()
    {
        lock (Gate)
        {
            if (_loaded) return;
            _loaded = true;

            // Walk up from bin/<config>/<tfm>/ looking for the project root. `.env` is the
            // strongest signal; the .csproj is the fallback so .auth/ still lands somewhere
            // predictable when no .env exists (a cached session, no credentials).
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            string? envFile = null;

            for (var i = 0; i < 8 && dir is not null; i++, dir = dir.Parent)
            {
                var candidate = Path.Combine(dir.FullName, ".env");
                if (File.Exists(candidate))
                {
                    envFile = candidate;
                    AnchorDirectory = dir.FullName;
                    break;
                }

                if (Directory.EnumerateFiles(dir.FullName, "*.csproj").Any())
                {
                    AnchorDirectory = dir.FullName;
                }
            }

            if (envFile is null) return;

            foreach (var raw in File.ReadAllLines(envFile))
            {
                var line = raw.Trim();
                if (line.Length == 0 || line[0] is '#') continue;

                var split = line.IndexOf('=');
                if (split <= 0) continue;

                var key = line[..split].Trim();
                var value = line[(split + 1)..].Trim();

                // Strip one layer of matching quotes - a password with a trailing space, or a
                // '#' in it, has to be quotable.
                if (value.Length >= 2 &&
                    ((value[0] is '"' && value[^1] is '"') || (value[0] is '\'' && value[^1] is '\'')))
                {
                    value = value[1..^1];
                }

                if (Environment.GetEnvironmentVariable(key) is null)
                {
                    Environment.SetEnvironmentVariable(key, value);
                }
            }
        }
    }
}
