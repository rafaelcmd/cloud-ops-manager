package consumer

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"

	"github.com/rafaelcmd/internal-developer-platform/resource-provisioner-service/internal/logger"
)

// RunSQS long-polls the queue and deletes each message after processing
// (at-least-once) until the context is cancelled.
func RunSQS(ctx context.Context, client *sqs.Client, queueURL string, tracer trace.Tracer, metrics Metrics, log logger.Logger) error {
	log.WithContext(ctx).Info("polling messages from SQS queue", logger.F("queue_url", queueURL))

	for ctx.Err() == nil {
		pollCtx, pollSpan := tracer.Start(ctx, "PollSQSMessages")

		output, err := client.ReceiveMessage(pollCtx, &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(queueURL),
			MaxNumberOfMessages: 5,
			WaitTimeSeconds:     10,
			// Ask SQS to return the trace-context attributes the API injected on
			// publish; without this they are dropped and the trace breaks.
			MessageAttributeNames: []string{"All"},
		})
		if err != nil {
			pollSpan.RecordError(err)
			pollSpan.End()
			// A cancelled context is a clean shutdown, not a poll failure.
			if ctx.Err() != nil {
				break
			}
			log.WithContext(pollCtx).Error("failed to receive messages", logger.F("error", err.Error()))
			continue
		}
		metrics.Received.Add(pollCtx, int64(len(output.Messages)))

		for _, message := range output.Messages {
			// Continue the API's trace: the producer span it injected into the
			// message attributes becomes the parent of ProcessMessage, so the
			// whole provisioning flow is one distributed trace and the logs
			// below share the API's trace_id.
			msgCtx := extractSQS(pollCtx, message.MessageAttributes)
			processCtx, span := tracer.Start(msgCtx, "ProcessMessage")
			log.WithContext(processCtx).Info("received message", logger.F("body", aws.ToString(message.Body)))

			// Control-plane step: decode the request and separate it into the
			// scaffold and infrastructure halves. See Dispatch for the point at
			// which the state machine executions will be started.
			if !Dispatch(processCtx, []byte(aws.ToString(message.Body)), tracer, log) {
				span.SetStatus(codes.Error, "provision request could not be understood")
			}

			// Delete the message after processing.
			_, err := client.DeleteMessage(processCtx, &sqs.DeleteMessageInput{
				QueueUrl:      aws.String(queueURL),
				ReceiptHandle: message.ReceiptHandle,
			})
			if err != nil {
				metrics.Failed.Add(processCtx, 1)
				span.RecordError(err)
				log.WithContext(processCtx).Error("failed to delete message", logger.F("error", err.Error()))
			} else {
				metrics.Processed.Add(processCtx, 1)
				log.WithContext(processCtx).Info("message deleted")
			}
			span.End()
		}

		pollSpan.End()
	}

	return ctx.Err()
}
