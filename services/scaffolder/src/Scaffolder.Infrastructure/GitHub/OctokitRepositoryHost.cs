using Microsoft.Extensions.Logging;
using Octokit;
using Scaffolder.Domain.Errors;
using Scaffolder.Domain.Model;
using Scaffolder.Domain.Ports;

namespace Scaffolder.Infrastructure.GitHub;

/// <summary>
/// The GitHub implementation of <see cref="IRepositoryHost"/>.
///
/// Only two Octokit failures are translated into domain errors — "already
/// exists" and "not found". Everything else (a 5xx, a rate limit, an expired
/// token) is left to propagate as-is, on purpose: those are transient, and the
/// worker's deletion rule leaves the message on the queue for redelivery. Turning
/// them into domain errors would report a permanent failure to the state machine
/// for something that would have worked thirty seconds later.
/// </summary>
public sealed class OctokitRepositoryHost(
    IGitHubClientFactory clients,
    ILogger<OctokitRepositoryHost> logger) : IRepositoryHost
{
    public async Task<HostedRepository> CreateAsync(
        RepositoryBlueprint blueprint,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(blueprint);

        var client = await clients.GetClientAsync(cancellationToken);

        var request = new NewRepository(blueprint.Name.Value)
        {
            Description = blueprint.Description,
            Private = blueprint.Private,

            // Without an initial commit there is no default branch, and every
            // later step — the scaffold push, branch protection, CI — has nothing
            // to attach to.
            AutoInit = blueprint.AutoInitialize,
        };

        try
        {
            var created = await client.Repository.Create(blueprint.Owner, request);

            return Map(created);
        }
        catch (RepositoryExistsException)
        {
            logger.LogWarning(
                "GitHub reports {Owner}/{Name} already exists",
                blueprint.Owner,
                blueprint.Name.Value);

            throw new RepositoryAlreadyExistsException(blueprint.Owner, blueprint.Name.Value);
        }
    }

    public async Task<HostedRepository?> FindAsync(
        string owner,
        string name,
        CancellationToken cancellationToken = default)
    {
        var client = await clients.GetClientAsync(cancellationToken);

        try
        {
            return Map(await client.Repository.Get(owner, name));
        }
        catch (NotFoundException)
        {
            return null;
        }
    }

    private static HostedRepository Map(Repository repository) => new(
        repository.Id,
        repository.Owner.Login,
        repository.Name,
        repository.HtmlUrl,
        repository.CloneUrl,
        repository.DefaultBranch);
}
