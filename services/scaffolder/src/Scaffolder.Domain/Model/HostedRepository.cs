namespace Scaffolder.Domain.Model;

/// <summary>
/// A repository as the hosting provider reports it. Deliberately the small
/// subset the platform needs — id, coordinates, the two URLs and the default
/// branch — rather than a mirror of GitHub's payload, so swapping the host does
/// not ripple into the domain.
/// </summary>
/// <param name="Id">The host's own identifier. Survives a rename, which the name does not.</param>
/// <param name="CloneUrl">HTTPS clone URL; what the push task will write to.</param>
/// <param name="DefaultBranch">Branch the host initialised, needed before anything can be pushed.</param>
public sealed record HostedRepository(
    long Id,
    string Owner,
    string Name,
    string HtmlUrl,
    string CloneUrl,
    string DefaultBranch)
{
    public string FullName => $"{Owner}/{Name}";
}
