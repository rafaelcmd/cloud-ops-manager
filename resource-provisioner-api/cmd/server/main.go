package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"log"
	"net/http"
)

var (
	sqsClient *sqs.Client
	queueUrl  string
)

func main() {
	//brokers := []string{"kafka:9092"}
	//topic := "resource-provisioner"

	//repo := repository.NewKafkaResourceRepository(brokers, topic)
	//defer repo.Close()

	//useCase := usecase.NewResourceUseCase(repo)

	//router := httpdelivery.SetupRoutes(useCase)

	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion("us-east-1"))
	if err != nil {
		log.Fatalf("unable to load AWS config, %v", err)
	}

	sqsClient = sqs.NewFromConfig(cfg)

	queueUrl = "https://sqs.us-east-1.amazonaws.com/471112701237/resource_provisioner_queue"

	log.Printf("Server running on port 5000")
	http.ListenAndServe(":5000", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/resource-provisioner" {
			handleProvisionRequest(w, r)
		} else {
			http.NotFound(w, r)
		}
	}))
}

func handleProvisionRequest(w http.ResponseWriter, r *http.Request) {
	payload := map[string]interface{}{
		"action":   "provision",
		"resource": "ec2",
		"source":   "cloudops-manager",
	}

	body, err := json.Marshal(payload)
	if err != nil {
		http.Error(w, "Failed to encode message", http.StatusInternalServerError)
		return
	}

	_, err = sqsClient.SendMessage(context.TODO(), &sqs.SendMessageInput{
		QueueUrl:    aws.String(queueUrl),
		MessageBody: aws.String(string(body)),
	})

	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to send message: %v", err), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusAccepted)
	w.Write([]byte("Message sent to SQS"))
}
