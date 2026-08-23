package sqs

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	sqstypes "github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"go.opentelemetry.io/otel"

	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/errors"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/model"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/ports/outbound"
)

// ResourcePublisher publishes resource provisioning requests to SQS.
type ResourcePublisher struct {
	client   *sqs.Client
	queueURL string
}

// Ensure ResourcePublisher implements the ResourcePublisher interface.
var _ outbound.ResourcePublisher = (*ResourcePublisher)(nil)

// NewResourcePublisher creates a new ResourcePublisher.
func NewResourcePublisher(client *sqs.Client, queueURL string) *ResourcePublisher {
	return &ResourcePublisher{
		client:   client,
		queueURL: queueURL,
	}
}

// Publish sends a resource provisioning request to the SQS queue.
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
	// the message attributes so the provisioner can continue this trace: its
	// ProcessMessage span becomes a child of this producer span and both
	// services' logs share one trace_id. No-op when tracing is disabled.
	attrs := sqsAttributeCarrier{}
	otel.GetTextMapPropagator().Inject(ctx, attrs)

	input := &sqs.SendMessageInput{
		MessageBody: aws.String(string(body)),
		QueueUrl:    aws.String(p.queueURL),
	}
	if len(attrs) > 0 {
		input.MessageAttributes = attrs
	}

	if _, err = p.client.SendMessage(ctx, input); err != nil {
		return errors.NewDomainError(
			errors.ErrCodeQueueError,
			fmt.Sprintf("failed to publish provision request %s to queue", request.RequestID),
			err,
		)
	}

	return nil
}

// sqsAttributeCarrier adapts SQS message attributes to OTel's TextMapCarrier so
// the global propagator can write trace context onto an outgoing message.
type sqsAttributeCarrier map[string]sqstypes.MessageAttributeValue

func (c sqsAttributeCarrier) Get(key string) string {
	if v, ok := c[key]; ok && v.StringValue != nil {
		return *v.StringValue
	}
	return ""
}

func (c sqsAttributeCarrier) Set(key, value string) {
	c[key] = sqstypes.MessageAttributeValue{
		DataType:    aws.String("String"),
		StringValue: aws.String(value),
	}
}

func (c sqsAttributeCarrier) Keys() []string {
	keys := make([]string, 0, len(c))
	for k := range c {
		keys = append(keys, k)
	}
	return keys
}
