using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Base64Url = System.Buffers.Text.Base64Url;

namespace Scaffolder.Infrastructure.GitHub;

/// <summary>
/// Builds the RS256 JWT GitHub expects from an app.
///
/// Assembled by hand rather than with a JWT library: it is two base64url
/// segments and one signature, and a dependency would earn its place only if we
/// also had to <em>validate</em> tokens, which this service never does. Kept in
/// its own type so it can be tested against a real key without a network.
/// </summary>
public static class GitHubAppJwt
{
    /// <summary>GitHub rejects an app JWT with more than 10 minutes of life; stay under it.</summary>
    public static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(9);

    /// <summary>
    /// Clock skew between us and GitHub makes a JWT issued "now" occasionally
    /// look future-dated. Backdating it is what GitHub's own documentation
    /// recommends.
    /// </summary>
    public static readonly TimeSpan Backdate = TimeSpan.FromSeconds(60);

    /// <param name="appId">The App's id — not the installation id.</param>
    /// <param name="privateKeyPem">
    /// PEM private key. Both PKCS#1 ("BEGIN RSA PRIVATE KEY", what GitHub hands
    /// out) and PKCS#8 ("BEGIN PRIVATE KEY", what an openssl conversion
    /// produces) are accepted.
    /// </param>
    public static string Create(string appId, string privateKeyPem, DateTimeOffset now)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(appId);
        ArgumentException.ThrowIfNullOrWhiteSpace(privateKeyPem);

        var header = Segment(new Dictionary<string, object>
        {
            ["alg"] = "RS256",
            ["typ"] = "JWT",
        });

        var payload = Segment(new Dictionary<string, object>
        {
            ["iat"] = now.Subtract(Backdate).ToUnixTimeSeconds(),
            ["exp"] = now.Add(Lifetime).ToUnixTimeSeconds(),
            ["iss"] = appId,
        });

        var signingInput = $"{header}.{payload}";

        using var rsa = RSA.Create();
        rsa.ImportFromPem(privateKeyPem);

        var signature = rsa.SignData(
            Encoding.UTF8.GetBytes(signingInput),
            HashAlgorithmName.SHA256,
            RSASignaturePadding.Pkcs1);

        return $"{signingInput}.{Base64Url.EncodeToString(signature)}";
    }

    private static string Segment(Dictionary<string, object> claims) =>
        Base64Url.EncodeToString(JsonSerializer.SerializeToUtf8Bytes(claims));
}
