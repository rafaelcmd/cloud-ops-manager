namespace Scaffolder.Application.CreateRepository;

/// <summary>Input to the <c>CreateRepository</c> state machine task.</summary>
/// <param name="ApplicationName">The name <c>ReserveName</c> already claimed for this request.</param>
/// <param name="RequestId">Correlation id of the provisioning request. Replays reuse it.</param>
/// <param name="Template">Golden path the repository will be scaffolded from, recorded on the inventory item.</param>
/// <param name="Description">Optional repository description; a default is used when the caller omits it.</param>
public sealed record CreateRepositoryCommand(
    string ApplicationName,
    string RequestId,
    string Template,
    string? Description = null);

/// <summary>Output of the <c>CreateRepository</c> task, passed to the next state.</summary>
/// <param name="AlreadyExisted">
/// True when this same request had already created the repository — the
/// at-least-once case where the host accepted the call but the outcome never got
/// back to us. Handled as a no-op rather than an error.
/// </param>
public sealed record CreateRepositoryResult(
    string Owner,
    string Name,
    string FullName,
    string HtmlUrl,
    string CloneUrl,
    string DefaultBranch,
    bool AlreadyExisted);

/// <summary>
/// Tunables for the use case, bound from environment variables by the
/// composition root.
/// </summary>
/// <param name="Owner">
/// The organization every repository is created under. Deliberately not part of
/// the command: the GitHub App is installed on exactly one org, and letting a
/// message name its own target would make the request the authority on where it
/// writes.
/// </param>
/// <param name="Private">Scaffolded repositories start private; making one public is a deliberate act.</param>
/// <param name="AutoInitialize">Ask the host for an initial commit so there is a default branch to push to.</param>
public sealed record CreateRepositoryOptions(
    string Owner,
    bool Private = true,
    bool AutoInitialize = true);
