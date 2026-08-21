using Microsoft.Extensions.Logging.Abstractions;
using Scaffolder.Domain.Errors;
using Scaffolder.Domain.Ports;
using Scaffolder.Domain.ValueObjects;
using Scaffolder.Infrastructure.Configuration;
using Scaffolder.Infrastructure.GitHub;

namespace Scaffolder.IntegrationTests;

/// <summary>
/// The GitHub adapter against the real API. Everything else about this service
/// can be verified without a network; authenticating as a GitHub App cannot —
/// the JWT, the installation lookup and the token exchange all fail in ways only
/// GitHub can tell you about.
///
/// It creates and deletes real repositories, so it runs only against the
/// throwaway sandbox org and only when the suite is explicitly enabled. Requires
/// <c>GITHUB_ORG</c>, <c>GITHUB_APP_ID</c> and <c>GITHUB_APP_KEY_SECRET_ARN</c>,
/// plus AWS credentials that can read that secret.
/// </summary>
public sealed class CreateRepositoryIntegrationTests
{
    // xUnit 2 has no runtime skip, so the gate is an early return rather than a
    // Skip attribute — a disabled run reports green because the test did nothing,
    // which is the same contract IntegrationTestGate documents.
    [Fact]
    public async Task Creates_a_repository_and_finds_it_again()
    {
        if (!Enabled)
        {
            return;
        }

        var host = Host();
        var name = ApplicationName.Parse($"idp-probe-{DateTimeOffset.UtcNow:yyyyMMddHHmmss}");
        var owner = Options().Organization;

        var created = await host.CreateAsync(
            new RepositoryBlueprint(owner, name, "Temporary probe from the scaffolder test suite", Private: true, AutoInitialize: true),
            CancellationToken.None);

        try
        {
            Assert.Equal($"{owner}/{name.Value}", created.FullName);

            // AutoInit is what gives the repository a default branch; without one
            // every later scaffold step has nothing to push to.
            Assert.False(string.IsNullOrWhiteSpace(created.DefaultBranch));

            var found = await host.FindAsync(owner, name.Value, CancellationToken.None);
            Assert.Equal(created.Id, found?.Id);

            // The second create is what a redelivery does. It must be a domain
            // conflict, which is the signal the use case reads to decide whether
            // to adopt or fail.
            await Assert.ThrowsAsync<RepositoryAlreadyExistsException>(
                () => host.CreateAsync(
                    new RepositoryBlueprint(owner, name, "duplicate", Private: true, AutoInitialize: true),
                    CancellationToken.None));
        }
        finally
        {
            await DeleteAsync(owner, name.Value);
        }
    }

    [Fact]
    public async Task A_repository_that_does_not_exist_is_null_rather_than_an_error()
    {
        if (!Enabled)
        {
            return;
        }

        Assert.Null(await Host().FindAsync(
            Options().Organization,
            "idp-probe-definitely-not-a-real-repository",
            CancellationToken.None));
    }

    private static bool Enabled =>
        IntegrationTestGate.Enabled
        && Environment.GetEnvironmentVariable("GITHUB_ORG") is { Length: > 0 };

    private static GitHubOptions Options() =>
        GitHubOptions.FromEnvironment()
        ?? throw new InvalidOperationException("GITHUB_ORG must be set to run the GitHub adapter tests");

    private static OctokitRepositoryHost Host() => new(
        Factory(),
        NullLogger<OctokitRepositoryHost>.Instance);

    private static GitHubAppClientFactory Factory() => new(
        new Amazon.SecretsManager.AmazonSecretsManagerClient(),
        Options(),
        TimeProvider.System,
        NullLogger<GitHubAppClientFactory>.Instance);

    /// <summary>
    /// Deleting needs the <c>delete_repo</c> permission on the App. Without it the
    /// probe repositories pile up in the sandbox, which is survivable — the org
    /// exists to be filled with rubbish — so a failure here does not fail the test.
    /// </summary>
    private static async Task DeleteAsync(string owner, string name)
    {
        try
        {
            var client = await Factory().GetClientAsync(CancellationToken.None);
            await client.Repository.Delete(owner, name);
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine($"could not delete probe repository {owner}/{name}: {exception.Message}");
        }
    }
}
