using Octokit;

namespace Scaffolder.Infrastructure.GitHub;

/// <summary>
/// Hands out a GitHub client that is authenticated right now. Installation
/// tokens expire after an hour, so adapters must ask for a client per operation
/// rather than holding one — the factory decides whether that means reusing the
/// cached client or minting a new token.
/// </summary>
public interface IGitHubClientFactory
{
    Task<IGitHubClient> GetClientAsync(CancellationToken cancellationToken = default);
}
