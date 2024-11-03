package main

import (
	"context"
	"fmt"
	"github.com/segmentio/kafka-go"
	"log"
	"os"
)

func main() {
	brokerAddress := os.Getenv("KAFKA_BROKER")
	topic := "resource-provisioner"

	r := kafka.NewReader(kafka.ReaderConfig{
		Brokers:   []string{brokerAddress},
		Topic:     topic,
		GroupID:   "resource-provisioner",
		Partition: 0,
	})

	defer r.Close()

	fmt.Println("Kafka consumer started")
	for {
		msg, err := r.ReadMessage(context.Background())
		if err != nil {
			log.Printf("Error reading message: %v", err)
			continue
		}

		fmt.Printf("Received message: %s\n", string(msg.Value))
	}
}
