using Amazon.SQS;
using Amazon.StepFunctions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Scaffolder.Application.CreateRepository;
using Scaffolder.Application.ReserveName;
using Scaffolder.Infrastructure;
using Scaffolder.Infrastructure.Configuration;
using Scaffolder.Worker;

// Amazon.StepFunctions also defines a LogLevel (the state machine's own logging
// configuration). Alias so the logging builder below reads unambiguously.
using LogLevel = Microsoft.Extensions.Logging.LogLevel;

// Composition root. Configuration is read first and validated on the spot, so a
// missing table name or queue URL fails the process at startup - visible as a
// CrashLoopBackOff - instead of surfacing as a null reference on the first task.
var options = ScaffolderOptions.FromEnvironment();

var builder = Host.CreateApplicationBuilder(args);

// stdout as single-line JSON: the Collector ships it, and it matches the shape
// the Go services log in, so one Datadog query spans all three.
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(console =>
{
    console.IncludeScopes = true;
    console.JsonWriterOptions = new System.Text.Json.JsonWriterOptions { Indented = false };
});
builder.Logging.SetMinimumLevel(LogLevel.Information);

builder.Services.AddScaffolderInfrastructure(options);

// AWS clients are singletons so credentials and TLS connections are established
// once and reused for the life of the pod, not per message. Region and
// credentials come from the environment: IRSA in-cluster, LocalStack locally.
builder.Services.AddSingleton<IAmazonSQS>(_ => new AmazonSQSClient());
builder.Services.AddSingleton<IAmazonStepFunctions>(_ => new AmazonStepFunctionsClient());

// Every task this build implements, whether or not this pod serves it.
string[] knownTasks = ["ReserveName", "CreateRepository"];

// An empty allowlist means "everything this build knows about".
bool Enabled(string task) => options.EnabledTasks.Count == 0 || options.EnabledTasks.Contains(task);

// Which tasks this pod serves. The two Deployments run this same image and
// differ here: the state worker gets ReserveName, the GitHub worker gets
// CreateRepository and the IAM role that can read the App key. An empty
// allowlist means everything, which is only useful for a single local container.
if (Enabled("ReserveName"))
{
    builder.Services.AddSingleton(new ReserveNameOptions(options.ReservationTtl));
    builder.Services.AddSingleton<ReserveNameUseCase>();
    builder.Services.AddSingleton<IScaffoldTask>(services => new ScaffoldTask<ReserveNameCommand, ReserveNameResult>(
        "ReserveName",
        services.GetRequiredService<ReserveNameUseCase>().ExecuteAsync));
}

// GitHub tasks are the one place the allowlist is not purely additive. Named
// explicitly and unconfigured is an error — someone meant this pod to do GitHub
// work and it cannot. Included only by the empty-means-everything default and
// unconfigured just means this pod does no GitHub work, which is what keeps a
// bare `dotnet run` and the local container useful without an App key.
if (options.EnabledTasks.Contains("CreateRepository")
    || (options.EnabledTasks.Count == 0 && options.GitHub is not null))
{
    // Fail here rather than on the first message. A pod that cannot authenticate
    // to GitHub would otherwise poll happily, take a task, and dead-letter it.
    var gitHub = options.GitHub
        ?? throw new InvalidOperationException(
            "SCAFFOLDER_TASKS names CreateRepository but GITHUB_ORG is not set; "
            + "this deployment cannot reach GitHub");

    builder.Services.AddSingleton(new CreateRepositoryOptions(gitHub.Organization));
    builder.Services.AddSingleton<CreateRepositoryUseCase>();
    builder.Services.AddSingleton<IScaffoldTask>(services => new ScaffoldTask<CreateRepositoryCommand, CreateRepositoryResult>(
        "CreateRepository",
        services.GetRequiredService<CreateRepositoryUseCase>().ExecuteAsync));
}

// A name in SCAFFOLDER_TASKS that matches nothing above is a typo in a manifest,
// and a typo that silently narrows what a pod does is the kind that survives to
// production. Refuse to start instead.
var unknownTasks = options.EnabledTasks.Except(knownTasks, StringComparer.OrdinalIgnoreCase).ToArray();

if (unknownTasks.Length > 0)
{
    throw new InvalidOperationException(
        $"SCAFFOLDER_TASKS names unknown tasks: {string.Join(", ", unknownTasks)}. "
        + $"This build knows {string.Join(", ", knownTasks)}");
}

builder.Services.AddSingleton<TaskDispatcher>();
builder.Services.AddHostedService<TaskQueueWorker>();

// Telemetry is opt-in on the endpoint being set, so a local run stays quiet
// instead of retrying an exporter that has nowhere to go. In-cluster the
// Deployment always sets it.
if (options.OtlpEndpoint is not null)
{
    builder.Services.AddOpenTelemetry()
        .ConfigureResource(resource => resource
            .AddService(options.ServiceName, serviceVersion: options.ServiceVersion)
            .AddAttributes([new KeyValuePair<string, object>("deployment.environment", options.Environment)]))
        .WithTracing(tracing => tracing
            .AddSource(ScaffolderTelemetry.ActivitySourceName)
            // Instruments the SDK calls themselves, so a slow DynamoDB write
            // shows as its own span rather than unexplained time in the task.
            .AddAWSInstrumentation()
            .AddOtlpExporter())
        .WithMetrics(metrics => metrics
            .AddRuntimeInstrumentation()
            .AddOtlpExporter());
}

await builder.Build().RunAsync();
