using System.Security.Cryptography;

namespace Tests.UI.Authentication;

/// <summary>
/// RFC 6238 time-based one-time passwords, so an account with MFA can still sign in headlessly.
/// </summary>
/// <remarks>
/// This is the same trick TALXIS.TestKit uses (UserConfiguration.OtpToken): register the test
/// account's authenticator with a seed you keep, and the run can produce the six digits itself.
/// The seed is the base32 string shown next to the QR code when you add an authenticator app.
///
/// A seed is a second factor in a file, which is worth being honest about: it belongs to a test
/// account that should have no standing access to anything, never to a human's account.
/// </remarks>
public static class Totp
{
    private const int DigitCount = 6;
    private const int StepSeconds = 30;

    public static string Generate(string base32Secret, DateTimeOffset? at = null)
    {
        var key = DecodeBase32(base32Secret);
        var counter = (at ?? DateTimeOffset.UtcNow).ToUnixTimeSeconds() / StepSeconds;

        var counterBytes = BitConverter.GetBytes(counter);
        if (BitConverter.IsLittleEndian) Array.Reverse(counterBytes);

        var hash = HMACSHA1.HashData(key, counterBytes);

        // Dynamic truncation: the low nibble of the last byte picks where to read from.
        var offset = hash[^1] & 0x0F;
        var binary = ((hash[offset] & 0x7F) << 24)
                     | (hash[offset + 1] << 16)
                     | (hash[offset + 2] << 8)
                     | hash[offset + 3];

        return (binary % (int)Math.Pow(10, DigitCount)).ToString(new string('0', DigitCount));
    }

    /// <summary>
    /// Base32 (RFC 4648) without the padding/whitespace fuss - authenticator seeds get copied out
    /// of QR dialogs in groups of four, lower-cased, and with '=' sometimes trimmed.
    /// </summary>
    private static byte[] DecodeBase32(string input)
    {
        const string Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

        var bytes = new List<byte>();
        var buffer = 0;
        var bitsInBuffer = 0;

        foreach (var raw in input)
        {
            if (raw is '=' || char.IsWhiteSpace(raw) || raw is '-') continue;

            var index = Alphabet.IndexOf(char.ToUpperInvariant(raw));
            if (index < 0)
            {
                throw new FormatException(
                    $"'{raw}' is not valid base32. An authenticator seed is A-Z and 2-7 only.");
            }

            buffer = (buffer << 5) | index;
            bitsInBuffer += 5;

            if (bitsInBuffer >= 8)
            {
                bitsInBuffer -= 8;
                bytes.Add((byte)(buffer >> bitsInBuffer));
            }
        }

        if (bytes.Count == 0)
        {
            throw new FormatException("The authenticator seed is empty.");
        }

        return bytes.ToArray();
    }
}
