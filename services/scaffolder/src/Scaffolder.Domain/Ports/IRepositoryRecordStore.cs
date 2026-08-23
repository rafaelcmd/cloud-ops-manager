using Scaffolder.Domain.Errors;
using Scaffolder.Domain.Model;

namespace Scaffolder.Domain.Ports;

/// <summary>What happened when a repository slot was claimed.</summary>
public enum RepositoryClaimOutcome
{
    /// <summary>No record existed; this request now owns the repository.</summary>
    Created,

    /// <summary>This same request already claimed it — a redelivery, not a conflict.</summary>
    AlreadyHeldByThisRequest,
}

/// <summary>
/// The platform's inventory of repositories it created. Like
/// <see cref="INameReservationStore"/>, the claim must be a single atomic
/// conditional write: it is the only thing that lets a redelivered task tell its
/// own half-finished attempt from a genuine name collision.
/// </summary>
public interface IRepositoryRecordStore
{
    /// <summary>Claims the repository slot for <paramref name="record"/>'s request.</summary>
    /// <exception cref="RepositoryAlreadyExistsException">A different request already claimed it.</exception>
    Task<RepositoryClaimOutcome> ClaimAsync(RepositoryRecord record, CancellationToken cancellationToken = default);

    /// <summary>
    /// Records that the repository now exists. Must be conditional on the claim
    /// still belonging to this request, so a task that lost a race cannot
    /// overwrite the winner's record.
    /// </summary>
    Task SaveCreatedAsync(RepositoryRecord record, CancellationToken cancellationToken = default);
}
