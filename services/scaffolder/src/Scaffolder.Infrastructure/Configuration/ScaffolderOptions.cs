namespace Scaffolder.Infrastructure.Configuration;

/// <summary>
/// Everything this service reads from its environment. Set on the container by
/// <c>k8s/scaffolder/deployment.yaml</c>; there is deliberately no config file.
/// Values that Terraform owns - the table name and the task queue URL - are
/// resolved from SSM Parameter Store at deploy time rather than hard-coded here.
/// </summary>
public sealed record ScaffolderOptions
{
    public required string TableName { get; init; }

    /// <summary>
    /// Name - not URL - of the queue the state machine drops
    /// <c>.waitForTaskToken</c> messages on. The worker resolves it to a URL at
    /// startup, which keeps the account id out of the committed manifest and
    /// works unchanged against LocalStack.
    /// </summary>
    public required string TaskQueueName { get; init; }

    public required TimeSpan ReservationTtl { get; init; }

    /// <summary>
    /// Which tasks this pod is allowed to run, from <c>SCAFFOLDER_TASKS</c>.
    /// Empty means every task the binary knows about, which is what makes a
    /// single local container useful; both Deployments set it explicitly.
    ///
    /// This is not a security control on its own — the IAM role and the
    /// per-deployment queue are. It is what turns a misrouted message into a
    /// loud failure instead of a call the pod has no credentials to make.
    /// </summary>
    public required IReadOnlySet<string> EnabledTasks { get; init; }

    /// <summary>
    /// GitHub App configuration, or null on a pod that runs no GitHub tasks.
    /// </summary>
    public GitHubOptions? GitHub { get; init; }

    public required string ServiceName { get; init; }

    public required string ServiceVersion { get; init; }

    public required string Environment { get; init; }

    /// <summary>
    /// OTLP endpoint of the in-cluster Collector. Null disables telemetry export
    /// entirely, which is what makes `dotnet run` on a laptop quiet - the same
    /// no-op-when-unset rule the Go services follow.
    /// </summary>
    public string? OtlpEndpoint { get; init; }

    /// <summary>
    /// Reads the environment once, at startup. Missing required values throw
    /// here rather than on the first message, so a misconfigured Deployment
    /// crash-loops immediately instead of silently draining its queue.
    /// </summary>
    public static ScaffolderOptions FromEnvironment() => new()
    {
        TableName = Required("SCAFFOLDER_TABLE_NAME"),
        TaskQueueName = Required("SCAFFOLDER_TASK_QUEUE_NAME"),
        ReservationTtl = TimeSpan.FromMinutes(OptionalInt("SCAFFOLDER_RESERVATION_TTL_MINUTES", 360)),
        EnabledTasks = ParseTasks(System.Environment.GetEnvironmentVariable("SCAFFOLDER_TASKS")),
        GitHub = GitHubOptions.FromEnvironment(),
        ServiceName = Optional("SERVICE_NAME", "scaffolder"),
        ServiceVersion = Optional("SERVICE_VERSION", "0.0.0-dev"),
        Environment = Optional("ENVIRONMENT", "dev"),
        OtlpEndpoint = System.Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT") is { Length: > 0 } endpoint
            ? endpoint
            : null,
    };

    /// <summary>
    /// Splits the comma-separated allowlist. Case-insensitive because the task
    /// names come from a state machine definition, where the casing is a
    /// human's choice rather than a contract.
    /// </summary>
    private static IReadOnlySet<string> ParseTasks(string? value) =>
        string.IsNullOrWhiteSpace(value)
            ? new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            : value.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

    private static string Required(string key)
    {
        var value = System.Environment.GetEnvironmentVariable(key);
        return string.IsNullOrWhiteSpace(value)
            ? throw new InvalidOperationException($"required environment variable {key} is not set")
            : value;
    }

    private static string Optional(string key, string fallback)
    {
        var value = System.Environment.GetEnvironmentVariable(key);
        return string.IsNullOrWhiteSpace(value) ? fallback : value;
    }

    private static int OptionalInt(string key, int fallback)
    {
        var value = System.Environment.GetEnvironmentVariable(key);

        if (string.IsNullOrWhiteSpace(value))
        {
            return fallback;
        }

        return int.TryParse(value, out var parsed) && parsed > 0
            ? parsed
            : throw new InvalidOperationException($"environment variable {key} must be a positive integer, got '{value}'");
    }
}
