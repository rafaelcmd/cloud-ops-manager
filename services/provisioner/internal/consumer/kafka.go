package consumer

import (
	"context"

	"github.com/segmentio/kafka-go"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"

	"github.com/rafaelcmd/internal-developer-platform/resource-provisioner-service/internal/logger"
)

// KafkaConfig configures the Kafka consumer.
type KafkaConfig struct {
	Brokers []string
	Topic   string
	GroupID string
}

// RunKafka consumes the provisioning topic with a consumer group until the
// context is cancelled. Offsets are committed only after a message is processed
// (at-least-once), mirroring the SQS delete-after-process semantics.
func RunKafka(ctx context.Context, cfg KafkaConfig, tracer trace.Tracer, metrics Metrics, log logger.Logger) error {
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers: cfg.Brokers,
		Topic:   cfg.Topic,
		GroupID: cfg.GroupID,
	})
	defer func() {
		if err := reader.Close(); err != nil {
			log.WithContext(ctx).Warn("failed to close Kafka reader", logger.F("error", err.Error()))
		}
	}()

	log.WithContext(ctx).Info("consuming messages from Kafka",
		logger.F("topic", cfg.Topic),
		logger.F("group", cfg.GroupID),
	)

	for ctx.Err() == nil {
		message, err := reader.FetchMessage(ctx)
		if err != nil {
			// A cancelled context is a clean shutdown, not a fetch failure.
			if ctx.Err() != nil {
				break
			}
			log.WithContext(ctx).Error("failed to fetch message", logger.F("error", err.Error()))
			continue
		}
		metrics.Received.Add(ctx, 1)

		// Continue the API's trace: the producer span it injected into the
		// message headers becomes the parent of ProcessMessage, so the whole
		// provisioning flow is one distributed trace and the logs below share
		// the API's trace_id.
		msgCtx := extractKafka(ctx, message.Headers)
		processCtx, span := tracer.Start(msgCtx, "ProcessMessage")
		log.WithContext(processCtx).Info("received message", logger.F("body", string(message.Value)))

		// Control-plane step, identical to the SQS path so that local development
		// exercises the same separation as the deployed environments.
		if !Dispatch(processCtx, message.Value, tracer, log) {
			span.SetStatus(codes.Error, "provision request could not be understood")
		}

		// Commit the offset after processing.
		if err := reader.CommitMessages(processCtx, message); err != nil {
			metrics.Failed.Add(processCtx, 1)
			span.RecordError(err)
			log.WithContext(processCtx).Error("failed to commit message", logger.F("error", err.Error()))
		} else {
			metrics.Processed.Add(processCtx, 1)
			log.WithContext(processCtx).Info("message committed")
		}
		span.End()
	}

	return ctx.Err()
}
