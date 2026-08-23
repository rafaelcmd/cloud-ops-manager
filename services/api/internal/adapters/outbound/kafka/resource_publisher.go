// Package kafka provides a Kafka-backed implementation of the ResourcePublisher
// port, used in local development in place of SQS so the full
// API -> queue -> provisioner flow runs offline without AWS.
package kafka

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/segmentio/kafka-go"
	"go.opentelemetry.io/otel"

	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/errors"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/model"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/ports/outbound"
)

// ResourcePublisher publishes resource provisioning requests to a Kafka topic.
type ResourcePublisher struct {
	writer *kafka.Writer
}

// Ensure ResourcePublisher implements the ResourcePublisher interface.
var _ outbound.ResourcePublisher = (*ResourcePublisher)(nil)

// NewResourcePublisher creates a publisher writing to the given topic on the
// given brokers. AllowAutoTopicCreation makes the topic appear on first write,
// which suits the local Kafka stack.
func NewResourcePublisher(brokers []string, topic string) *ResourcePublisher {
	return &ResourcePublisher{
		writer: &kafka.Writer{
			Addr:                   kafka.TCP(brokers...),
			Topic:                  topic,
			Balancer:               &kafka.Hash{},
			AllowAutoTopicCreation: true,
		},
	}
}

// Publish serializes the request and writes it to Kafka. Messages are keyed by
// application name so that every message for one application is written to the
// same partition and consumed in order; keying by request id would distribute
// them across partitions and lose that guarantee.
func (p *ResourcePublisher) Publish(ctx context.Context, request model.ProvisionRequest) error {
	body, err := json.Marshal(request)
	if err != nil {
		return errors.NewDomainError(
			errors.ErrCodeQueueError,
			"failed to serialize provision request for publishing",
			err,
		)
	}

	// Inject the active trace context (W3C traceparent/tracestate/baggage) into
	// the message headers so the provisioner can continue this trace: its
	// ProcessMessage span becomes a child of this producer span and both
	// services' logs share one trace_id. No-op when tracing is disabled.
	var headers []kafka.Header
	otel.GetTextMapPropagator().Inject(ctx, kafkaHeaderCarrier{headers: &headers})

	err = p.writer.WriteMessages(ctx, kafka.Message{
		Key:     []byte(request.Application.Name),
		Value:   body,
		Headers: headers,
	})
	if err != nil {
		return errors.NewDomainError(
			errors.ErrCodeQueueError,
			fmt.Sprintf("failed to publish provision request %s to kafka", request.RequestID),
			err,
		)
	}

	return nil
}

// Close flushes and releases the underlying Kafka writer.
func (p *ResourcePublisher) Close() error {
	return p.writer.Close()
}

// kafkaHeaderCarrier adapts Kafka message headers to OTel's TextMapCarrier so
// the global propagator can write trace context onto an outgoing message.
type kafkaHeaderCarrier struct {
	headers *[]kafka.Header
}

func (c kafkaHeaderCarrier) Get(key string) string {
	for _, h := range *c.headers {
		if h.Key == key {
			return string(h.Value)
		}
	}
	return ""
}

func (c kafkaHeaderCarrier) Set(key, value string) {
	for i := range *c.headers {
		if (*c.headers)[i].Key == key {
			(*c.headers)[i].Value = []byte(value)
			return
		}
	}
	*c.headers = append(*c.headers, kafka.Header{Key: key, Value: []byte(value)})
}

func (c kafkaHeaderCarrier) Keys() []string {
	keys := make([]string, 0, len(*c.headers))
	for _, h := range *c.headers {
		keys = append(keys, h.Key)
	}
	return keys
}
