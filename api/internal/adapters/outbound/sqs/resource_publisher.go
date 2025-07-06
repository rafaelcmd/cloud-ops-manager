package sqs

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/model"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/ports/outbound"
)

type ResourcePublisher struct {
	client   *sqs.Client
	queueURL string
}

var _ outbound.ResourcePublisher = &ResourcePublisher{}

func NewResourcePublisher(client *sqs.Client, queueURL string) *ResourcePublisher {
	return &ResourcePublisher{
		client:   client,
		queueURL: queueURL,
	}
}

func (p *ResourcePublisher) Publish(ctx context.Context, resource model.Resource) error {
	body, err := json.Marshal(resource)
	if err != nil {
		return fmt.Errorf("failed to marshal resource: %w", err)
	}

	_, err = p.client.SendMessage(ctx, &sqs.SendMessageInput{
		MessageBody: aws.String(string(body)),
		QueueUrl:    aws.String(p.queueURL),
	})
	if err != nil {
		return fmt.Errorf("failed to send message to SQS: %w", err)
	}

	return nil
}
