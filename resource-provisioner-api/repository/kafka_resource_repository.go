package repository

import (
	"context"
	"encoding/json"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/core/domain"
	"github.com/segmentio/kafka-go"
	"log"
)

type KafkaResourceRepository struct {
	writer *kafka.Writer
}

func NewKafkaResourceRepository(brokers []string, topic string) *KafkaResourceRepository {
	if len(brokers) == 0 {
		panic("No Kafka brokers provided")
	}

	if topic == "" {
		panic("No Kafka topic provided")
	}

	writer := &kafka.Writer{
		Addr:     kafka.TCP(brokers...),
		Topic:    topic,
		Balancer: &kafka.LeastBytes{},
	}

	return &KafkaResourceRepository{writer: writer}
}

func (r *KafkaResourceRepository) CreateResource(resource *domain.Resource) error {
	message, err := json.Marshal(resource)
	if err != nil {
		return err
	}

	err = r.writer.WriteMessages(
		context.Background(),
		kafka.Message{
			Key:   []byte(resource.ID),
			Value: message,
		},
	)
	if err != nil {
		log.Printf("Failed to publish Kafka event: %v", err)
		return err
	}
	log.Printf("Published Kafka event for resource %s", resource.ID)
	return nil
}

func (r *KafkaResourceRepository) Close() {
	if err := r.writer.Close(); err != nil {
		log.Printf("Failed to close Kafka writer: %v", err)
	}
}
