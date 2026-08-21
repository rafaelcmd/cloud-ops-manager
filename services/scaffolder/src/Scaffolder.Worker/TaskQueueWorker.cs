using System.Diagnostics;
using System.Text.Json;
using Amazon.SQS;
using Amazon.SQS.Model;
using Amazon.StepFunctions;
using Amazon.StepFunctions.Model;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Scaffolder.Domain.Errors;
using Scaffolder.Infrastructure.Configuration;

namespace Scaffolder.Worker;

/// <summary>
/// Long-polls the scaffold task queue and runs whatever the state machine asked
/// for.
/// <para>
/// The contract is Step Functions' <c>.waitForTaskToken</c> pattern: the machine
/// hands us a token on the queue, we do the work for as long as it takes, and we
/// report the outcome with <c>SendTaskSuccess</c> or <c>SendTaskFailure</c>. The
/// same pattern the Infra Worker uses for its Terraform runs.
/// </para>
/// <para>
/// <b>Deletion rule:</b> a message is deleted only once its outcome has reached
/// Step Functions. Anything else - an unparseable body, a missing token, a
/// Secrets Manager blip - is left on the queue, so SQS redelivers it and the
/// DLQ catches it after <c>maxReceiveCount</c>. Deleting on failure would strand
/// the execution until its task timeout with nothing to look at.
/// </para>
/// </summary>
internal sealed class TaskQueueWorker(
    IAmazonSQS sqs,
    IAmazonStepFunctions stepFunctions,
    TaskDispatcher dispatcher,
    ScaffolderOptions options,
    ILogger<TaskQueueWorker> logger) : BackgroundService
{
    // Long polling: one API call parked for 20s rather than a spin of empty
    // receives. At this traffic volume that is the whole cost of the consumer.
    private const int WaitTimeSeconds = 20;
    private const int MaxMessagesPerReceive = 10;

    private static readonly TimeSpan ReceiveErrorBackoff = TimeSpan.FromSeconds(5);

    private string queueUrl = string.Empty;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        queueUrl = await ResolveQueueUrlAsync(stoppingToken);

        if (stoppingToken.IsCancellationRequested)
        {
            return;
        }

        logger.LogInformation(
            "Scaffolder worker started; polling {QueueUrl} for tasks {KnownTasks}",
            queueUrl,
            string.Join(", ", dispatcher.KnownTasks));

        while (!stoppingToken.IsCancellationRequested)
        {
            List<Message> messages;

            try
            {
                var response = await sqs.ReceiveMessageAsync(
                    new ReceiveMessageRequest
                    {
                        QueueUrl = queueUrl,
                        MaxNumberOfMessages = MaxMessagesPerReceive,
                        WaitTimeSeconds = WaitTimeSeconds,
                        MessageSystemAttributeNames = ["ApproximateReceiveCount"],
                    },
                    stoppingToken);

                // AWS SDK v4 leaves collections null rather than empty.
                messages = response.Messages ?? [];
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (AmazonSQSException exception)
            {
                // Throttling, a transient network fault, or IRSA credentials not
                // yet projected into the pod. Back off rather than hot-looping.
                logger.LogError(exception, "Receive from {QueueUrl} failed; retrying", queueUrl);
                await SafeDelayAsync(ReceiveErrorBackoff, stoppingToken);
                continue;
            }

            foreach (var message in messages)
            {
                if (stoppingToken.IsCancellationRequested)
                {
                    break;
                }

                await HandleAsync(message, stoppingToken);
            }
        }

        logger.LogInformation("Scaffolder worker stopped");
    }

    private async Task HandleAsync(Message message, CancellationToken cancellationToken)
    {
        TaskEnvelope? envelope;

        try
        {
            envelope = JsonSerializer.Deserialize<TaskEnvelope>(message.Body, TaskDispatcher.Json);
        }
        catch (JsonException exception)
        {
            // Left on the queue on purpose: there is no token to fail against,
            // and the DLQ is where a malformed payload should end up.
            logger.LogError(exception, "Unparseable task message {MessageId}; leaving for the DLQ", message.MessageId);
            return;
        }

        if (envelope is null || string.IsNullOrWhiteSpace(envelope.TaskToken))
        {
            logger.LogError("Task message {MessageId} carries no task token; leaving for the DLQ", message.MessageId);
            return;
        }

        using var activity = ScaffolderTelemetry.ActivitySource.StartActivity(
            $"scaffold.task {envelope.Task}",
            ActivityKind.Consumer);

        activity?.SetTag("scaffold.task", envelope.Task);
        activity?.SetTag("messaging.message.id", message.MessageId);

        try
        {
            var output = await dispatcher.DispatchAsync(envelope, cancellationToken);

            await stepFunctions.SendTaskSuccessAsync(
                new SendTaskSuccessRequest { TaskToken = envelope.TaskToken, Output = output },
                cancellationToken);

            logger.LogInformation("Task {Task} succeeded for message {MessageId}", envelope.Task, message.MessageId);

            await DeleteAsync(message, cancellationToken);
        }
        catch (ScaffolderException exception)
        {
            // An expected domain outcome. On Lambda the error name was whatever
            // the runtime reported - the short exception type. Here the worker
            // chooses it, so a Catch clause matches the domain's own stable
            // Code instead of a name that changes if the class is renamed.
            await FailAsync(envelope, message, exception.Code, exception.Message, exception, cancellationToken);
        }
        catch (UnknownScaffolderTaskException exception)
        {
            await FailAsync(envelope, message, "UNKNOWN_TASK", exception.Message, exception, cancellationToken);
        }
        catch (JsonException exception)
        {
            await FailAsync(envelope, message, "INVALID_TASK_PAYLOAD", exception.Message, exception, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            // Shutdown mid-task. Leave the message; SQS redelivers it to the
            // next pod once the visibility timeout lapses.
            logger.LogInformation("Shutting down mid-task {Task}; message {MessageId} will be redelivered", envelope.Task, message.MessageId);
        }
        catch (Exception exception)
        {
            // A bug or an infrastructure fault. Not reported as a task failure:
            // this is the class of error a retry can actually fix.
            activity?.SetStatus(ActivityStatusCode.Error, exception.Message);
            logger.LogError(exception, "Task {Task} threw; leaving message {MessageId} for redelivery", envelope.Task, message.MessageId);
        }
    }

    private async Task FailAsync(
        TaskEnvelope envelope,
        Message message,
        string error,
        string cause,
        Exception exception,
        CancellationToken cancellationToken)
    {
        Activity.Current?.SetStatus(ActivityStatusCode.Error, cause);
        logger.LogWarning(exception, "Task {Task} failed with {Error}", envelope.Task, error);

        // This runs inside a catch block in HandleAsync, so it has to handle its
        // own failures: an exception thrown from a catch is not caught by that
        // try's other clauses. It would escape ExecuteAsync and stop the host,
        // which is how one expired task token could take the pod down.
        try
        {
            await stepFunctions.SendTaskFailureAsync(
                new SendTaskFailureRequest
                {
                    TaskToken = envelope.TaskToken,
                    // Error is capped at 256 characters by the API.
                    Error = error.Length <= 256 ? error : error[..256],
                    Cause = cause,
                },
                cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            return;
        }
        catch (Exception callbackFailure)
        {
            // The outcome never reached Step Functions, so by the deletion rule
            // the message stays on the queue. The execution is stuck either way
            // — a token we cannot fail against is usually one that already timed
            // out — but redelivery and the DLQ keep the evidence.
            logger.LogError(
                callbackFailure,
                "Could not report {Error} for task {Task}; leaving message {MessageId} for redelivery",
                error,
                envelope.Task,
                message.MessageId);

            return;
        }

        await DeleteAsync(message, cancellationToken);
    }

    private async Task DeleteAsync(Message message, CancellationToken cancellationToken) =>
        await sqs.DeleteMessageAsync(queueUrl, message.ReceiptHandle, cancellationToken);

    /// <summary>
    /// Turns the configured queue name into a URL. Retried rather than fatal:
    /// on a cold cluster the pod can start before its IRSA credentials are
    /// projected, and crash-looping over a condition that clears itself in
    /// seconds only obscures the real failures.
    /// </summary>
    private async Task<string> ResolveQueueUrlAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                var response = await sqs.GetQueueUrlAsync(options.TaskQueueName, cancellationToken);
                return response.QueueUrl;
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                logger.LogError(
                    exception,
                    "Could not resolve queue {TaskQueueName}; retrying in {Backoff}s",
                    options.TaskQueueName,
                    ReceiveErrorBackoff.TotalSeconds);

                await SafeDelayAsync(ReceiveErrorBackoff, cancellationToken);
            }
        }

        return string.Empty;
    }

    private static async Task SafeDelayAsync(TimeSpan delay, CancellationToken cancellationToken)
    {
        try
        {
            await Task.Delay(delay, cancellationToken);
        }
        catch (OperationCanceledException)
        {
            // Shutting down during a backoff is not an error.
        }
    }
}
