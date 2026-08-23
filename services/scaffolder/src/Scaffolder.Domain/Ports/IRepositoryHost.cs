using Scaffolder.Domain.Errors;
using Scaffolder.Domain.Model;
using Scaffolder.Domain.ValueObjects;

namespace Scaffolder.Domain.Ports;

/// <summary>What the platform asks the host to create.</summary>
/// <param name="AutoInitialize">
/// Ask the host for an initial commit. Without it the repository has no default
/// branch, and everything downstream — branch protection, the first push, CI —
/// has nothing to attach to.
/// </param>
public sealed record RepositoryBlueprint(
    string Owner,
    ApplicationName Name,
    string Description,
    bool Private,
    bool AutoInitialize);

/// <summary>
/// The repository hosting provider. One implementation today (GitHub, via a
/// GitHub App), but the domain is written against this rather than against
/// Octokit so the use case can be tested without a network.
/// </summary>
public interface IRepositoryHost
{
    /// <summary>Creates the repository under <paramref name="blueprint"/>'s owner.</summary>
    /// <exception cref="RepositoryAlreadyExistsException">The host already has a repository with that name.</exception>
    Task<HostedRepository> CreateAsync(RepositoryBlueprint blueprint, CancellationToken cancellationToken = default);

    /// <summary>Looks a repository up, returning null when the host does not have it.</summary>
    Task<HostedRepository?> FindAsync(string owner, string name, CancellationToken cancellationToken = default);
}
