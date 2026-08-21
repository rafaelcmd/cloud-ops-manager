using Scaffolder.Domain.ValueObjects;

namespace Scaffolder.Domain.Model;

/// <summary>Lifecycle of a repository this platform owns.</summary>
public enum RepositoryStatus
{
    /// <summary>The request has claimed the slot but the repository does not exist on the host yet.</summary>
    Claimed,

    /// <summary>The repository exists on the host.</summary>
    Created,
}

/// <summary>
/// The platform's record of a repository it created — the <c>REPO#&lt;owner&gt;/&lt;name&gt;</c>
/// item. It is written <em>before</em> the repository exists, which is what makes
/// creation replay-safe: the claim is a conditional write, so a redelivery can
/// tell its own earlier attempt from someone else's repository.
/// </summary>
public sealed record RepositoryRecord
{
    private RepositoryRecord(
        string owner,
        ApplicationName name,
        string requestId,
        string template,
        RepositoryStatus status,
        DateTimeOffset createdAt,
        HostedRepository? hosted)
    {
        Owner = owner;
        Name = name;
        RequestId = requestId;
        Template = template;
        Status = status;
        CreatedAt = createdAt;
        Hosted = hosted;
    }

    /// <summary>Organization login the repository lives under.</summary>
    public string Owner { get; }

    public ApplicationName Name { get; }

    public string FullName => $"{Owner}/{Name.Value}";

    /// <summary>The request that owns this repository. A replay reuses it; a different one is a conflict.</summary>
    public string RequestId { get; }

    /// <summary>Golden path this repository was scaffolded from. Answers the day-2 drift question.</summary>
    public string Template { get; }

    public RepositoryStatus Status { get; }

    public DateTimeOffset CreatedAt { get; }

    /// <summary>What the host reported once the repository existed. Null while the record is only a claim.</summary>
    public HostedRepository? Hosted { get; }

    public static RepositoryRecord Claim(
        string owner,
        ApplicationName name,
        string requestId,
        string template,
        DateTimeOffset now)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(owner);
        ArgumentException.ThrowIfNullOrWhiteSpace(requestId);
        ArgumentException.ThrowIfNullOrWhiteSpace(template);

        return new RepositoryRecord(owner, name, requestId, template, RepositoryStatus.Claimed, now, hosted: null);
    }

    /// <summary>Promotes the claim once the host confirms the repository exists.</summary>
    public RepositoryRecord MarkCreated(HostedRepository hosted)
    {
        ArgumentNullException.ThrowIfNull(hosted);

        if (!string.Equals(hosted.FullName, FullName, StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException(
                $"cannot mark '{FullName}' created from a different repository '{hosted.FullName}'",
                nameof(hosted));
        }

        return new RepositoryRecord(Owner, Name, RequestId, Template, RepositoryStatus.Created, CreatedAt, hosted);
    }

    public static RepositoryRecord Rehydrate(
        string owner,
        ApplicationName name,
        string requestId,
        string template,
        RepositoryStatus status,
        DateTimeOffset createdAt,
        HostedRepository? hosted) => new(owner, name, requestId, template, status, createdAt, hosted);
}
