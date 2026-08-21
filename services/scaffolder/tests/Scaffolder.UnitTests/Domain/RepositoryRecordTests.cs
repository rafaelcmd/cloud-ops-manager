using Scaffolder.Domain.Model;
using Scaffolder.Domain.ValueObjects;

namespace Scaffolder.UnitTests.Domain;

public sealed class RepositoryRecordTests
{
    private static readonly DateTimeOffset Now = new(2026, 8, 20, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void A_claim_starts_before_the_repository_exists()
    {
        var record = Claim();

        Assert.Equal(RepositoryStatus.Claimed, record.Status);
        Assert.Null(record.Hosted);
        Assert.Equal("idp-scaffolder-sandbox/payments-api", record.FullName);
    }

    [Fact]
    public void Marking_it_created_keeps_the_claim_and_attaches_the_hosts_answer()
    {
        var record = Claim().MarkCreated(Hosted());

        Assert.Equal(RepositoryStatus.Created, record.Status);
        Assert.Equal(42, record.Hosted!.Id);

        // The request and the creation time belong to the claim, not to the host
        // response — a redelivery must not look like a newer record.
        Assert.Equal("req-1", record.RequestId);
        Assert.Equal(Now, record.CreatedAt);
    }

    [Fact]
    public void A_record_cannot_be_completed_from_a_different_repository()
    {
        // Guards the adopt-on-replay path: if a lookup ever returned the wrong
        // repository, this is what stops the platform recording it as ours.
        var mismatch = Hosted() with { Name = "billing-api" };

        Assert.Throws<ArgumentException>(() => Claim().MarkCreated(mismatch));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void A_claim_needs_a_request_to_belong_to(string requestId) =>
        Assert.Throws<ArgumentException>(() => RepositoryRecord.Claim(
            "idp-scaffolder-sandbox",
            ApplicationName.Parse("payments-api"),
            requestId,
            "dotnet-consumer",
            Now));

    [Fact]
    public void A_claim_needs_the_template_it_came_from() =>
        Assert.Throws<ArgumentException>(() => RepositoryRecord.Claim(
            "idp-scaffolder-sandbox",
            ApplicationName.Parse("payments-api"),
            "req-1",
            template: "",
            Now));

    private static RepositoryRecord Claim() => RepositoryRecord.Claim(
        "idp-scaffolder-sandbox",
        ApplicationName.Parse("payments-api"),
        "req-1",
        "dotnet-consumer",
        Now);

    private static HostedRepository Hosted() => new(
        42,
        "idp-scaffolder-sandbox",
        "payments-api",
        "https://github.com/idp-scaffolder-sandbox/payments-api",
        "https://github.com/idp-scaffolder-sandbox/payments-api.git",
        "main");
}
