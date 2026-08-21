using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Scaffolder.Infrastructure.GitHub;
using Base64Url = System.Buffers.Text.Base64Url;

namespace Scaffolder.UnitTests.Infrastructure;

/// <summary>
/// The app JWT is hand-rolled, so it gets tested against a real key rather than
/// trusted. A malformed one fails as a 401 from GitHub with no detail, which is
/// a miserable thing to debug from a pod log.
/// </summary>
public sealed class GitHubAppJwtTests
{
    private static readonly DateTimeOffset Now = new(2026, 8, 20, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void Signs_with_the_app_key_so_github_can_verify_it()
    {
        using var key = RSA.Create(2048);

        var token = GitHubAppJwt.Create("4608314", key.ExportRSAPrivateKeyPem(), Now);
        var parts = token.Split('.');

        Assert.Equal(3, parts.Length);
        Assert.True(key.VerifyData(
            Encoding.UTF8.GetBytes($"{parts[0]}.{parts[1]}"),
            Base64Url.DecodeFromChars(parts[2]),
            HashAlgorithmName.SHA256,
            RSASignaturePadding.Pkcs1));
    }

    [Fact]
    public void Declares_rs256_which_is_the_only_algorithm_github_accepts()
    {
        using var key = RSA.Create(2048);

        var header = Decode(GitHubAppJwt.Create("4608314", key.ExportRSAPrivateKeyPem(), Now), segment: 0);

        Assert.Equal("RS256", header.GetProperty("alg").GetString());
        Assert.Equal("JWT", header.GetProperty("typ").GetString());
    }

    [Fact]
    public void Is_issued_by_the_app_backdated_and_short_lived()
    {
        using var key = RSA.Create(2048);

        var payload = Decode(GitHubAppJwt.Create("4608314", key.ExportRSAPrivateKeyPem(), Now), segment: 1);

        Assert.Equal("4608314", payload.GetProperty("iss").GetString());

        // Backdated against clock skew, and inside GitHub's 10-minute ceiling.
        Assert.Equal(Now.Subtract(GitHubAppJwt.Backdate).ToUnixTimeSeconds(), payload.GetProperty("iat").GetInt64());
        Assert.Equal(Now.Add(GitHubAppJwt.Lifetime).ToUnixTimeSeconds(), payload.GetProperty("exp").GetInt64());
        Assert.True(GitHubAppJwt.Lifetime < TimeSpan.FromMinutes(10));
    }

    [Fact]
    public void Accepts_a_pkcs8_key_because_an_openssl_round_trip_produces_one()
    {
        using var key = RSA.Create(2048);

        var token = GitHubAppJwt.Create("4608314", key.ExportPkcs8PrivateKeyPem(), Now);

        Assert.Equal(3, token.Split('.').Length);
    }

    [Fact]
    public void Rejects_an_empty_app_id_rather_than_signing_a_token_no_one_will_accept()
    {
        using var key = RSA.Create(2048);

        Assert.Throws<ArgumentException>(
            () => GitHubAppJwt.Create("  ", key.ExportRSAPrivateKeyPem(), Now));
    }

    private static JsonElement Decode(string token, int segment) =>
        JsonDocument.Parse(Base64Url.DecodeFromChars(token.Split('.')[segment])).RootElement.Clone();
}
