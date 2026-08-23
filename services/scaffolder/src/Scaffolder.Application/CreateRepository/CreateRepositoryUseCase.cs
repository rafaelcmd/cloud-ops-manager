using Microsoft.Extensions.Logging;
using Scaffolder.Domain.Errors;
using Scaffolder.Domain.Model;
using Scaffolder.Domain.Ports;
using Scaffolder.Domain.ValueObjects;

namespace Scaffolder.Application.CreateRepository;

/// <summary>
/// Second task of the scaffold state machine: create the repository the
/// developer asked for, under the platform's organization.
///
/// The order here is the whole design. The inventory record is claimed
/// <em>before</em> the repository is created, so the two failure modes stay
/// distinguishable when SQS redelivers the task:
///
/// <list type="bullet">
/// <item>Fresh claim, then the host says the name is taken → a repository we did
/// not create is sitting on the name. A real conflict, reported to the state
/// machine.</item>
/// <item>Replayed claim, then the host says the name is taken → our own earlier
/// attempt reached GitHub and the acknowledgement was lost. Adopt it and carry
/// on.</item>
/// </list>
///
/// Without the claim, those two are indistinguishable and the task has to guess:
/// fail and strand a perfectly good repository, or adopt and risk scaffolding
/// over someone else's.
/// </summary>
public sealed class CreateRepositoryUseCase(
    IRepositoryRecordStore records,
    IRepositoryHost host,
    TimeProvider timeProvider,
    CreateRepositoryOptions options,
    ILogger<CreateRepositoryUseCase> logger)
{
    public async Task<CreateRepositoryResult> ExecuteAsync(
        CreateRepositoryCommand command,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(command);

        // Parsed again rather than trusted from the previous state: the task is
        // reachable by anything that can write to the queue, and the name ends
        // up in a URL.
        var name = ApplicationName.Parse(command.ApplicationName);

        var claim = RepositoryRecord.Claim(
            options.Owner,
            name,
            command.RequestId,
            command.Template,
            timeProvider.GetUtcNow());

        var outcome = await records.ClaimAsync(claim, cancellationToken);

        var blueprint = new RepositoryBlueprint(
            options.Owner,
            name,
            command.Description ?? DefaultDescription(command.Template),
            options.Private,
            options.AutoInitialize);

        HostedRepository repository;
        bool alreadyExisted;

        try
        {
            repository = await host.CreateAsync(blueprint, cancellationToken);
            alreadyExisted = false;
        }
        catch (RepositoryAlreadyExistsException) when (outcome is RepositoryClaimOutcome.AlreadyHeldByThisRequest)
        {
            var existing = await host.FindAsync(options.Owner, name.Value, cancellationToken);

            if (existing is null)
            {
                // The host contradicted itself: it refused the create because the
                // name is taken, then could not find it. Rethrowing keeps the
                // conflict visible instead of inventing a repository.
                throw;
            }

            logger.LogInformation(
                "Repository {FullName} already existed from an earlier delivery of request {RequestId}; adopting it",
                existing.FullName,
                command.RequestId);

            repository = existing;
            alreadyExisted = true;
        }

        await records.SaveCreatedAsync(claim.MarkCreated(repository), cancellationToken);

        logger.LogInformation(
            "Created repository {FullName} from template {Template} for request {RequestId}",
            repository.FullName,
            command.Template,
            command.RequestId);

        return new CreateRepositoryResult(
            repository.Owner,
            repository.Name,
            repository.FullName,
            repository.HtmlUrl,
            repository.CloneUrl,
            repository.DefaultBranch,
            alreadyExisted);
    }

    private static string DefaultDescription(string template) =>
        $"Scaffolded from the {template} golden path by the internal developer platform.";
}
