using System.Text.Json;

namespace Scaffolder.Worker;

/// <summary>
/// One state machine task this pod can run. The set of these registered at
/// startup <em>is</em> the pod's capability list: the state worker and the GitHub
/// worker run the same image and differ only in which of these are wired up,
/// which queue they read, and which IAM role they hold.
/// </summary>
internal interface IScaffoldTask
{
    /// <summary>Matches the task name the state machine puts on the message.</summary>
    string Name { get; }

    Task<object> RunAsync(JsonElement input, CancellationToken cancellationToken);
}

/// <summary>
/// Adapts a use case's <c>ExecuteAsync</c> to <see cref="IScaffoldTask"/>. Binding
/// the payload is the only thing that happens here — a task with logic in it
/// would be logic that cannot be tested without a queue.
/// </summary>
internal sealed class ScaffoldTask<TCommand, TResult>(
    string name,
    Func<TCommand, CancellationToken, Task<TResult>> execute) : IScaffoldTask
    where TResult : notnull
{
    public string Name => name;

    public async Task<object> RunAsync(JsonElement input, CancellationToken cancellationToken)
    {
        var command = input.Deserialize<TCommand>(TaskDispatcher.Json)
            ?? throw new JsonException($"task payload deserialized to null for {typeof(TCommand).Name}");

        return await execute(command, cancellationToken);
    }
}
