package main

import (
	"context"
	"fmt"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/segmentio/kafka-go"
	"log"
	"net/http"
	"os"
)

var (
	consumedMessages = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "kafka_consumer_messages_total",
			Help: "The total number of messages consumed from Kafka",
		},
	)
	consumerErrors = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "kafka_consumer_errors_total",
			Help: "The total number of errors encountered while consuming messages from Kafka",
		},
	)
)

func init() {
	prometheus.MustRegister(consumedMessages)
	prometheus.MustRegister(consumerErrors)
}

func main() {
	go func() {
		http.Handle("/metrics", promhttp.Handler())
		log.Println("Starting metrics server on :5000")
		log.Fatal(http.ListenAndServe(":5000", nil))
	}()

	brokerAddress := os.Getenv("KAFKA_BROKER")
	topic := "resource-provisioner"

	r := kafka.NewReader(kafka.ReaderConfig{
		Brokers: []string{brokerAddress},
		Topic:   topic,
		GroupID: "resource-provisioner",
	})

	defer r.Close()

	fmt.Println("Kafka consumer started")
	for {
		msg, err := r.ReadMessage(context.Background())
		if err != nil {
			log.Printf("Error reading message: %v", err)
			consumerErrors.Inc()
			continue
		}

		fmt.Printf("Received message: %s\n", string(msg.Value))
		consumedMessages.Inc()
	}
}
