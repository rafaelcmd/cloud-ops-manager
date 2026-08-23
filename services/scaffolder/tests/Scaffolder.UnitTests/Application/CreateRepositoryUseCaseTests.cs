using Microsoft.Extensions.Logging.Abstractions;
using NSubstitute;
using NSubstitute.ExceptionExtensions;
using Scaffolder.Application.CreateRepository;
using Scaffolder.Domain.Errors;
using Scaffolder.Domain.Model;
using Scaffolder.Domain.Ports;

namespace Scaffolder.UnitTests.Application;

/// <summary>
/// The interesting behaviour here is not "it calls GitHub" — it is what happens
/// when the task runs twice, which at-least-once delivery guarantees it will.
/// </summary>
public sealed class CreateRepositoryUseCaseTests
{
    private const string Owner = "idp-scaffolder-sandbox";

    private readonly IRepositoryRecordStore records = Substitute.For<IRepositoryRecordStore>();
    private readonly IRepositoryHost host = Substitute.For<IRepositoryHost>();

    [Fact]
    public async Task Claims_the_inventory_slot_before_asking_the_host_to_create_anything()
    {
        // Ordering is the whole idempotency design: a repository that exists with
        // no record behind it is one nothing can safely adopt on redelivery.
        records.ClaimAsync(Arg.Any<RepositoryRecord>(), Arg.Any<CancellationToken>())
            .Returns(RepositoryClaimOutcome.Created);
        host.CreateAsync(Arg.Any<RepositoryBlueprint>(), Arg.Any<CancellationToken>())
            .Returns(Hosted());

        await UseCase().ExecuteAsync(Command(), CancellationToken.None);

        Received.InOrder(() =>
        {
            records.ClaimAsync(Arg.Any<RepositoryRecord>(), Arg.Any<CancellationToken>());
            host.CreateAsync(Arg.Any<RepositoryBlueprint>(), Arg.Any<CancellationToken>());
            records.SaveCreatedAsync(Arg.Any<RepositoryRecord>(), Arg.Any<CancellationToken>());
        });
    }

    [Fact]
    public async Task Creates_the_repository_and_records_where_it_landed()
    {
        records.ClaimAsync(Arg.Any<RepositoryRecord>(), Arg.Any<CancellationToken>())
            .Returns(RepositoryClaimOutcome.Created);
        host.CreateAsync(Arg.Any<RepositoryBlueprint>(), Arg.Any<CancellationToken>())
            .Returns(Hosted());

        var result = await UseCase().ExecuteAsync(Command(), CancellationToken.None);

        Assert.Equal($"{Owner}/payments-api", result.FullName);
        Assert.Equal("main", result.DefaultBranch);
        Assert.False(result.AlreadyExisted);

        await records.Received(1).SaveCreatedAsync(
            Arg.Is<RepositoryRecord>(record =>
                record.Status == RepositoryStatus.Created && record.Hosted!.Id == 42),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task The_owner_comes_from_configuration_not_from_the_message()
    {
        records.ClaimAsync(Arg.Any<RepositoryRecord>(), Arg.Any<CancellationToken>())
            .Returns(RepositoryClaimOutcome.Created);
        host.CreateAsync(Arg.Any<RepositoryBlueprint>(), Arg.Any<CancellationToken>())
            .Returns(Hosted());

        await UseCase().ExecuteAsync(Command(), CancellationToken.None);

        await host.Received(1).CreateAsync(
            Arg.Is<RepositoryBlueprint>(blueprint => blueprint.Owner == Owner && blueprint.Private),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task A_redelivery_that_finds_its_own_repository_adopts_it()
    {
        // The classic at-least-once case: GitHub created the repository, the
        // acknowledgement never got back, SQS redelivered. The claim replaying
        // is what proves the repository is ours.
        records.ClaimAsync(Arg.Any<RepositoryRecord>(), Arg.Any<CancellationToken>())
            .Returns(RepositoryClaimOutcome.AlreadyHeldByThisRequest);
        host.CreateAsync(Arg.Any<RepositoryBlueprint>(), Arg.Any<CancellationToken>())
            .Throws(new RepositoryAlreadyExistsException(Owner, "payments-api"));
        host.FindAsync(Owner, "payments-api", Arg.Any<CancellationToken>())
            .Returns(Hosted());

        var result = await UseCase().ExecuteAsync(Command(), CancellationToken.None);

        Assert.True(result.AlreadyExisted);
        Assert.Equal($"{Owner}/payments-api", result.FullName);
    }

    [Fact]
    public async Task A_first_attempt_that_hits_an_existing_repository_is_a_conflict()
    {
        // Fresh claim means we have never created this repository, so whatever is
        // sitting on the name belongs to someone else. Adopting it would scaffold
        // over a repository the platform does not own.
        records.ClaimAsync(Arg.Any<RepositoryRecord>(), Arg.Any<CancellationToken>())
            .Returns(RepositoryClaimOutcome.Created);
        host.CreateAsync(Arg.Any<RepositoryBlueprint>(), Arg.Any<CancellationToken>())
            .Throws(new RepositoryAlreadyExistsException(Owner, "payments-api"));

        var exception = await Assert.ThrowsAsync<RepositoryAlreadyExistsException>(
            () => UseCase().ExecuteAsync(Command(), CancellationToken.None));

        Assert.Equal("REPOSITORY_ALREADY_EXISTS", exception.Code);
        await host.DidNotReceive().FindAsync(
            Arg.Any<string>(), Arg.Any<string>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task A_host_that_reports_a_conflict_it_cannot_produce_is_not_papered_over()
    {
        records.ClaimAsync(Arg.Any<RepositoryRecord>(), Arg.Any<CancellationToken>())
            .Returns(RepositoryClaimOutcome.AlreadyHeldByThisRequest);
        host.CreateAsync(Arg.Any<RepositoryBlueprint>(), Arg.Any<CancellationToken>())
            .Throws(new RepositoryAlreadyExistsException(Owner, "payments-api"));
        host.FindAsync(Owner, "payments-api", Arg.Any<CancellationToken>())
            .Returns((HostedRepository?)null);

        await Assert.ThrowsAsync<RepositoryAlreadyExistsException>(
            () => UseCase().ExecuteAsync(Command(), CancellationToken.None));

        await records.DidNotReceive().SaveCreatedAsync(
            Arg.Any<RepositoryRecord>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task An_invalid_name_is_rejected_before_anything_is_claimed_or_created()
    {
        var exception = await Assert.ThrowsAsync<InvalidApplicationNameException>(
            () => UseCase().ExecuteAsync(Command() with { ApplicationName = "Payments_API" }, CancellationToken.None));

        Assert.Equal("INVALID_APPLICATION_NAME", exception.Code);
        await records.DidNotReceive().ClaimAsync(Arg.Any<RepositoryRecord>(), Arg.Any<CancellationToken>());
        await host.DidNotReceive().CreateAsync(Arg.Any<RepositoryBlueprint>(), Arg.Any<CancellationToken>());
    }

    private static CreateRepositoryCommand Command() =>
        new("payments-api", "req-1", "dotnet-consumer");

    private static HostedRepository Hosted() => new(
        42,
        Owner,
        "payments-api",
        $"https://github.com/{Owner}/payments-api",
        $"https://github.com/{Owner}/payments-api.git",
        "main");

    private CreateRepositoryUseCase UseCase() => new(
        records,
        host,
        TimeProvider.System,
        new CreateRepositoryOptions(Owner),
        NullLogger<CreateRepositoryUseCase>.Instance);
}
