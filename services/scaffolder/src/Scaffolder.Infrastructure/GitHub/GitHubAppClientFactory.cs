using Amazon.SecretsManager;
using Amazon.SecretsManager.Model;
using Microsoft.Extensions.Logging;
using Octokit;
using Scaffolder.Infrastructure.Configuration;

namespace Scaffolder.Infrastructure.GitHub;

/// <summary>
/// Authenticates as the platform's GitHub App: sign a short-lived JWT with the
/// App private key, exchange it for an installation token, use that to call the
/// API.
///
/// A GitHub App rather than a personal access token, because the difference is
/// the whole security story: tokens are scoped to the installation, expire in an
/// hour, and every repository the platform creates is attributable to the app
/// rather than to whichever engineer's account issued a PAT.
/// </summary>
public sealed class GitHubAppClientFactory : IGitHubClientFactory, IDisposable
{
    /// <summary>Renew before the installation token actually expires, so a long task cannot straddle the boundary.</summary>
    private static readonly TimeSpan RenewBefore = TimeSpan.FromMinutes(5);

    private readonly SemaphoreSlim gate = new(1, 1);
    private readonly IAmazonSecretsManager secrets;
    private readonly GitHubOptions options;
    private readonly TimeProvider timeProvider;
    private readonly ILogger<GitHubAppClientFactory> logger;
    private readonly ProductHeaderValue product;

    private string? privateKeyPem;
    private IGitHubClient? client;
    private DateTimeOffset tokenExpiresAt;

    public GitHubAppClientFactory(
        IAmazonSecretsManager secrets,
        GitHubOptions options,
        TimeProvider timeProvider,
        ILogger<GitHubAppClientFactory> logger)
    {
        this.secrets = secrets;
        this.options = options;
        this.timeProvider = timeProvider;
        this.logger = logger;

        // GitHub asks every client to identify itself; an unnamed one gets
        // rate-limited harder and is invisible in the org's audit log.
        product = new ProductHeaderValue("internal-developer-platform-scaffolder");
    }

    public async Task<IGitHubClient> GetClientAsync(CancellationToken cancellationToken = default)
    {
        if (client is not null && timeProvider.GetUtcNow() < tokenExpiresAt - RenewBefore)
        {
            return client;
        }

        await gate.WaitAsync(cancellationToken);

        try
        {
            // Re-check inside the gate: several tasks can queue on a single
            // expiry and only the first should mint.
            if (client is not null && timeProvider.GetUtcNow() < tokenExpiresAt - RenewBefore)
            {
                return client;
            }

            var token = await CreateInstallationTokenAsync(cancellationToken);

            client = new GitHubClient(product) { Credentials = new Credentials(token.Token) };
            tokenExpiresAt = token.ExpiresAt;

            logger.LogInformation(
                "Authenticated as GitHub App {AppId} on {Organization}; installation token expires {ExpiresAt:O}",
                options.AppId,
                options.Organization,
                tokenExpiresAt);

            return client;
        }
        finally
        {
            gate.Release();
        }
    }

    public void Dispose() => gate.Dispose();

    private async Task<AccessToken> CreateInstallationTokenAsync(CancellationToken cancellationToken)
    {
        var pem = await GetPrivateKeyAsync(cancellationToken);

        var appClient = new GitHubClient(product)
        {
            Credentials = new Credentials(
                GitHubAppJwt.Create(options.AppId, pem, timeProvider.GetUtcNow()),
                AuthenticationType.Bearer),
        };

        // Resolved at runtime rather than configured. The installation id changes
        // whenever the app is uninstalled and reinstalled; the org does not.
        var installation = await appClient.GitHubApps.GetOrganizationInstallationForCurrent(options.Organization);

        return await appClient.GitHubApps.CreateInstallationToken(installation.Id);
    }

    /// <summary>
    /// Reads the PEM once and keeps it for the life of the pod. Per-task reads
    /// would put a Secrets Manager call — and its failure modes — on every
    /// scaffold.
    /// </summary>
    private async Task<string> GetPrivateKeyAsync(CancellationToken cancellationToken)
    {
        if (privateKeyPem is not null)
        {
            return privateKeyPem;
        }

        var response = await secrets.GetSecretValueAsync(
            new GetSecretValueRequest { SecretId = options.AppPrivateKeySecretId },
            cancellationToken);

        var secret = response.SecretString;

        if (string.IsNullOrWhiteSpace(secret))
        {
            throw new InvalidOperationException(
                $"secret '{options.AppPrivateKeySecretId}' is empty; put the GitHub App's PEM private key in it");
        }

        // A key pasted through a JSON field or a shell arrives with literal
        // backslash-n instead of newlines, and ImportFromPem then fails with an
        // error that says nothing about why. Normalising costs nothing and saves
        // the next person an afternoon.
        var pem = secret.Contains("\\n", StringComparison.Ordinal)
            ? secret.Replace("\\n", "\n", StringComparison.Ordinal)
            : secret;

        if (!pem.Contains("-----BEGIN", StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                $"secret '{options.AppPrivateKeySecretId}' does not look like a PEM private key; "
                + "store the .pem file's contents as plaintext, not JSON");
        }

        privateKeyPem = pem;
        return pem;
    }
}
