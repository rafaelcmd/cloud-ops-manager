package consumer

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"

	"github.com/rafaelcmd/internal-developer-platform/resource-provisioner-service/internal/logger"
)

// SQSClient is the part of the SQS API this consumer uses. Narrowed to an
// interface so the receive/delete behaviour can be tested without AWS —
// *sqs.Client satisfies it.
type SQSClient interface {
	ReceiveMessage(context.Context, *sqs.ReceiveMessageInput, ...func(*sqs.Options)) (*sqs.ReceiveMessageOutput, error)
	DeleteMessage(context.Context, *sqs.DeleteMessageInput, ...func(*sqs.Options)) (*sqs.DeleteMessageOutput, error)
}

// RunSQS long-polls the queue until the context is cancelled, deleting each
// message once it has been handled (at-least-once). A message the consumer
// cannot understand is left on the queue for the redrive policy to move to the
// dead-letter queue.
func RunSQS(ctx context.Context, client SQSClient, queueURL string, tracer trace.Tracer, metrics Metrics, log logger.Logger) error {
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
				// Left on the queue deliberately. SQS makes it visible again
				// after the visibility timeout and the queue's redrive policy
				// moves it to the dead-letter queue once maxReceiveCount is
				// reached, where it can be looked at.
				//
				// Deleting here discarded the only copy of a request the service
				// could not understand, and told nobody: the API answered 202
				// long ago, so the caller waits for an application that will
				// never be scaffolded. It also meant the dead-letter queue could
				// never receive anything.
				span.SetStatus(codes.Error, "provision request could not be understood")
				metrics.Failed.Add(processCtx, 1)
				log.WithContext(processCtx).Error("leaving message on the queue for redelivery",
					logger.F("message_id", aws.ToString(message.MessageId)))
				span.End()
				continue
			}

			// Delete the message only once it has been handled.
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
