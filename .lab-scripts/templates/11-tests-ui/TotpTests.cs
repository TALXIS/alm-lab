using Tests.UI.Authentication;

namespace Tests.UI.Tests;

[TestClass]
public sealed class TotpTests
{
    // RFC 6238 Appendix B, SHA-1 vectors. The seed there is the ASCII string
    // "12345678901234567890", which is this in base32.
    private const string ReferenceSeed = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ";

    [TestMethod]
    [DataRow(59L, "287082")]
    [DataRow(1111111109L, "081804")]
    [DataRow(1111111111L, "050471")]
    [DataRow(1234567890L, "005924")]
    [DataRow(2000000000L, "279037")]
    public void Generate_matches_the_RFC_6238_vectors(long unixSeconds, string expected) =>
        Assert.AreEqual(expected, Totp.Generate(ReferenceSeed, DateTimeOffset.FromUnixTimeSeconds(unixSeconds)));

    [TestMethod]
    public void Generate_is_stable_inside_a_thirty_second_window()
    {
        var start = DateTimeOffset.FromUnixTimeSeconds(1111111080);

        Assert.AreEqual(
            Totp.Generate(ReferenceSeed, start),
            Totp.Generate(ReferenceSeed, start.AddSeconds(29)));
    }

    [TestMethod]
    public void Generate_rolls_at_the_window_boundary()
    {
        var start = DateTimeOffset.FromUnixTimeSeconds(1111111080);

        Assert.AreNotEqual(
            Totp.Generate(ReferenceSeed, start),
            Totp.Generate(ReferenceSeed, start.AddSeconds(30)));
    }

    [TestMethod]
    public void Generate_always_returns_six_digits() =>
        // A code that truncates to fewer digits must still be padded - 005924 above is the case
        // that catches this, but assert the shape explicitly too.
        Assert.IsTrue(
            Totp.Generate(ReferenceSeed, DateTimeOffset.FromUnixTimeSeconds(1234567890)) is { Length: 6 } code
            && code.All(char.IsDigit));

    [TestMethod]
    [DataRow("gezd gnbv gy3t qojq gezd gnbv gy3t qojq")]
    [DataRow("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ====")]
    [DataRow("GEZD-GNBV-GY3T-QOJQ-GEZD-GNBV-GY3T-QOJQ")]
    public void Generate_tolerates_how_seeds_are_actually_copied(string seed) =>
        // Authenticator dialogs show the seed lower-cased and in groups; people paste it as shown.
        Assert.AreEqual(
            Totp.Generate(ReferenceSeed, DateTimeOffset.FromUnixTimeSeconds(59)),
            Totp.Generate(seed, DateTimeOffset.FromUnixTimeSeconds(59)));

    [TestMethod]
    public void Generate_rejects_a_seed_that_is_not_base32() =>
        Assert.ThrowsExactly<FormatException>(() => Totp.Generate("not-a-seed-1!"));
}
