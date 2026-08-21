using Amazon.DynamoDBv2;
using Amazon.SecretsManager;
using Microsoft.Extensions.DependencyInjection;
using Scaffolder.Domain.Ports;
using Scaffolder.Infrastructure.Configuration;
using Scaffolder.Infrastructure.GitHub;
using Scaffolder.Infrastructure.Persistence;

namespace Scaffolder.Infrastructure;

public static class DependencyInjection
{
    /// <summary>
    /// Registers the adapters. Everything here is a singleton on purpose: the
    /// container is built once per execution context, so the AWS SDK clients -
    /// and the HTTPS connections and credentials they cache - survive across
    /// warm invocations instead of being rebuilt per request.
    /// </summary>
    public static IServiceCollection AddScaffolderInfrastructure(
        this IServiceCollection services,
        ScaffolderOptions options)
    {
        ArgumentNullException.ThrowIfNull(options);

        services.AddSingleton(options);
        services.AddSingleton(TimeProvider.System);
        services.AddSingleton<IAmazonDynamoDB>(_ => new AmazonDynamoDBClient());
        services.AddSingleton<INameReservationStore, DynamoDbNameReservationStore>();
        services.AddSingleton<IRepositoryRecordStore, DynamoDbRepositoryRecordStore>();

        if (options.GitHub is { } gitHub)
        {
            services.AddScaffolderGitHub(gitHub);
        }

        return services;
    }

    /// <summary>
    /// The GitHub adapter, registered only on a pod configured for it. Keeping
    /// this conditional is what lets one image serve both Deployments: the state
    /// worker never constructs a Secrets Manager client, and its IAM role could
    /// not use one if it did.
    /// </summary>
    private static void AddScaffolderGitHub(this IServiceCollection services, GitHubOptions options)
    {
        services.AddSingleton(options);
        services.AddSingleton<IAmazonSecretsManager>(_ => new AmazonSecretsManagerClient());
        services.AddSingleton<IGitHubClientFactory, GitHubAppClientFactory>();
        services.AddSingleton<IRepositoryHost, OctokitRepositoryHost>();
    }
}
