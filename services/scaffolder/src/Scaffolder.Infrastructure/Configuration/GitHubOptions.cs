namespace Scaffolder.Infrastructure.Configuration;

/// <summary>
/// Everything the GitHub adapter needs. Present only on the deployment that runs
/// GitHub tasks — the state worker has no business holding these, and its IAM
/// role cannot read the key they point at.
/// </summary>
public sealed record GitHubOptions
{
    /// <summary>Organization every scaffolded repository is created under.</summary>
    public required string Organization { get; init; }

    /// <summary>
    /// The GitHub App's id — not the installation id. The installation is
    /// resolved at runtime from the organization, so reinstalling the app (which
    /// changes the installation id) needs no config change.
    /// </summary>
    public required string AppId { get; init; }

    /// <summary>
    /// Secrets Manager id or ARN of the App's PEM private key. The key itself is
    /// never an environment variable: env vars show up in <c>kubectl describe</c>,
    /// in the manifest, and in every crash dump.
    /// </summary>
    public required string AppPrivateKeySecretId { get; init; }

    public static GitHubOptions? FromEnvironment()
    {
        var organization = Environment.GetEnvironmentVariable("GITHUB_ORG");

        // Absent org means this pod does not do GitHub work. Returning null here
        // rather than throwing is what lets one image serve both deployments.
        if (string.IsNullOrWhiteSpace(organization))
        {
            return null;
        }

        return new GitHubOptions
        {
            Organization = organization,
            AppId = Require("GITHUB_APP_ID"),
            AppPrivateKeySecretId = Require("GITHUB_APP_KEY_SECRET_ARN"),
        };
    }

    private static string Require(string key)
    {
        var value = Environment.GetEnvironmentVariable(key);

        return string.IsNullOrWhiteSpace(value)
            ? throw new InvalidOperationException(
                $"{key} is required when GITHUB_ORG is set: a pod configured for GitHub tasks must be able to authenticate")
            : value;
    }
}
