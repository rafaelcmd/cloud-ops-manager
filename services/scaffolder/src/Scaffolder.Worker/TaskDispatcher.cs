using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace Scaffolder.Worker;

/// <summary>
/// Maps a task name to the task that implements it and serializes the result. No
/// business logic lives here - exactly the rule the Lambda handlers followed,
/// which is why the use cases needed no changes when the runtime did.
///
/// It only knows about the tasks registered on <em>this</em> pod. A message for a
/// task this deployment does not serve is rejected rather than attempted, so a
/// misrouted message fails loudly instead of failing later inside an AWS call the
/// pod has no permission to make.
/// </summary>
internal sealed class TaskDispatcher
{
    /// <summary>
    /// Case-insensitive on the way in, property names as declared on the way
    /// out. That is the shape the state machine passes between states, and the
    /// shape the fixtures in <c>events/</c> are written in.
    /// </summary>
    public static readonly JsonSerializerOptions Json = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = false,
    };

    private readonly Dictionary<string, IScaffoldTask> handlers;
    private readonly ILogger<TaskDispatcher> logger;

    public TaskDispatcher(IEnumerable<IScaffoldTask> tasks, ILogger<TaskDispatcher> logger)
    {
        ArgumentNullException.ThrowIfNull(tasks);

        this.logger = logger;
        handlers = tasks.ToDictionary(task => task.Name, StringComparer.OrdinalIgnoreCase);

        if (handlers.Count == 0)
        {
            throw new InvalidOperationException(
                "no scaffold tasks are registered; check SCAFFOLDER_TASKS on this deployment");
        }
    }

    public IReadOnlyCollection<string> KnownTasks => handlers.Keys;

    /// <summary>Runs one task and returns its result as the JSON the state machine receives.</summary>
    /// <exception cref="UnknownScaffolderTaskException">This pod serves no handler for the task name.</exception>
    public async Task<string> DispatchAsync(TaskEnvelope envelope, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(envelope);

        if (!handlers.TryGetValue(envelope.Task, out var handler))
        {
            logger.LogError(
                "No handler for scaffold task {Task} on this deployment; it serves {KnownTasks}",
                envelope.Task,
                string.Join(", ", KnownTasks));

            throw new UnknownScaffolderTaskException(envelope.Task);
        }

        var result = await handler.RunAsync(envelope.Input, cancellationToken);

        return JsonSerializer.Serialize(result, result.GetType(), Json);
    }
}
