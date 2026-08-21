using System.Text.Json;
using Amazon.SQS;
using Amazon.SQS.Model;
using Amazon.StepFunctions;
using Amazon.StepFunctions.Model;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;
using NSubstitute;
using NSubstitute.ExceptionExtensions;
using Scaffolder.Infrastructure.Configuration;
using Scaffolder.Worker;

namespace Scaffolder.UnitTests.Worker;

/// <summary>
/// The worker's survival properties. A queue consumer that can be stopped by one
/// bad message is worse than no consumer: the pod restarts, picks the message up
/// again, and dies again, while every other task on the queue waits.
/// </summary>
public sealed class TaskQueueWorkerTests
{
    private const string QueueName = "internal-developer-platform-scaffolder-state-tasks-test";
    private const string QueueUrl = "https://sqs.us-east-1.amazonaws.com/000000000000/" + QueueName;

    private readonly IAmazonSQS sqs = Substitute.For<IAmazonSQS>();
    private readonly IAmazonStepFunctions stepFunctions = Substitute.For<IAmazonStepFunctions>();

    [Fact]
    public async Task A_callback_that_fails_does_not_take_the_host_down()
    {
        // The regression this exists for: SendTaskFailure is called from inside a
        // catch block, so an exception from it is not caught by that try's other
        // clauses. It escaped ExecuteAsync and stopped the host — one expired
        // task token was enough to crash-loop the pod.
        stepFunctions
            .SendTaskFailureAsync(Arg.Any<SendTaskFailureRequest>(), Arg.Any<CancellationToken>())
            .Throws(new Amazon.StepFunctions.Model.InvalidTokenException("token is not valid"));

        var drained = QueueReturning(Message("NoSuchTask", "{}"));
        var worker = Worker();

        await worker.StartAsync(CancellationToken.None);
        await drained.Task.WaitAsync(TimeSpan.FromSeconds(10));

        // StopAsync surfaces whatever ExecuteAsync threw, so a clean stop here is
        // the assertion.
        await worker.StopAsync(CancellationToken.None);

        // And the message is left for redelivery: the outcome never reached Step
        // Functions, so the deletion rule says it is not ours to delete.
        await sqs.DidNotReceive().DeleteMessageAsync(
            Arg.Any<string>(), Arg.Any<string>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Keeps_polling_after_a_message_it_cannot_handle()
    {
        stepFunctions
            .SendTaskFailureAsync(Arg.Any<SendTaskFailureRequest>(), Arg.Any<CancellationToken>())
            .Throws(new Amazon.StepFunctions.Model.InvalidTokenException("token is not valid"));

        var drained = QueueReturning(Message("NoSuchTask", "{}"));
        var worker = Worker();

        await worker.StartAsync(CancellationToken.None);
        await drained.Task.WaitAsync(TimeSpan.FromSeconds(10));
        await worker.StopAsync(CancellationToken.None);

        await sqs.Received().ReceiveMessageAsync(
            Arg.Any<ReceiveMessageRequest>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task A_message_with_no_task_token_is_left_for_the_dlq_without_a_callback()
    {
        var drained = QueueReturning(new Message
        {
            MessageId = "message-1",
            ReceiptHandle = "receipt-1",
            Body = """{ "Task": "ReserveName", "Input": {} }""",
        });

        var worker = Worker();

        await worker.StartAsync(CancellationToken.None);
        await drained.Task.WaitAsync(TimeSpan.FromSeconds(10));
        await worker.StopAsync(CancellationToken.None);

        // Nothing to report an outcome against, so neither callback is attempted
        // and the message stays put.
        await stepFunctions.DidNotReceive().SendTaskSuccessAsync(
            Arg.Any<SendTaskSuccessRequest>(), Arg.Any<CancellationToken>());
        await stepFunctions.DidNotReceive().SendTaskFailureAsync(
            Arg.Any<SendTaskFailureRequest>(), Arg.Any<CancellationToken>());
        await sqs.DidNotReceive().DeleteMessageAsync(
            Arg.Any<string>(), Arg.Any<string>(), Arg.Any<CancellationToken>());
    }

    /// <summary>
    /// Returns <paramref name="message"/> on the first receive and nothing after,
    /// completing the returned source once the loop has come back for more — which
    /// is the observable proof that the worker survived handling it.
    /// </summary>
    private TaskCompletionSource QueueReturning(Message message)
    {
        var drained = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var receives = 0;

        sqs.GetQueueUrlAsync(QueueName, Arg.Any<CancellationToken>())
            .Returns(new GetQueueUrlResponse { QueueUrl = QueueUrl });

        sqs.ReceiveMessageAsync(Arg.Any<ReceiveMessageRequest>(), Arg.Any<CancellationToken>())
            .Returns(_ =>
            {
                if (Interlocked.Increment(ref receives) == 1)
                {
                    return new ReceiveMessageResponse { Messages = [message] };
                }

                drained.TrySetResult();

                // AWS SDK v4 leaves collections null rather than empty; return the
                // shape the worker actually sees on an idle long poll.
                return new ReceiveMessageResponse { Messages = null };
            });

        return drained;
    }

    private static Message Message(string task, string input) => new()
    {
        MessageId = "message-1",
        ReceiptHandle = "receipt-1",
        Body = JsonSerializer.Serialize(
            new { Task = task, TaskToken = "token-1", Input = JsonDocument.Parse(input).RootElement },
            TaskDispatcher.Json),
    };

    private IHostedService Worker() => new TaskQueueWorker(
        sqs,
        stepFunctions,
        new TaskDispatcher(
            [new ScaffoldTask<object, object>("Noop", (_, _) => Task.FromResult<object>(new { }))],
            NullLogger<TaskDispatcher>.Instance),
        new ScaffolderOptions
        {
            TableName = "table",
            TaskQueueName = QueueName,
            ReservationTtl = TimeSpan.FromHours(6),
            EnabledTasks = new HashSet<string>(StringComparer.OrdinalIgnoreCase),
            ServiceName = "scaffolder",
            ServiceVersion = "test",
            Environment = "test",
        },
        NullLogger<TaskQueueWorker>.Instance);
}
