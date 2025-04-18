package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"log"
	"net/http"
)

var (
	sqsClient *sqs.Client
	ssmClient *ssm.Client
	queueUrl  string
)

func main() {
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion("us-east-1"))
	if err != nil {
		log.Fatalf("Unable to load AWS config, %v", err)
	}

	sqsClient = sqs.NewFromConfig(cfg)
	ssmClient = ssm.NewFromConfig(cfg)

	param, err := ssmClient.GetParameter(context.TODO(), &ssm.GetParameterInput{
		Name: aws.String("/CLOUD_OPS_MANAGER/SQS_QUEUE_URL"),
	})
	if err != nil {
		log.Fatalf("Unable to get SQS queue URL from Parameter Store, %v", err)
	}

	queueUrl = *param.Parameter.Value

	log.Printf("Server running on port 5000")
	err = http.ListenAndServe(":5000", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/resource-provisioner" && r.Method == http.MethodPost {
			handleProvisionPOSTRequest(w, r)
		} else if r.URL.Path == "/resource-provisioner" && r.Method == http.MethodGet {
			handleProvisionGETRequest(w, r)
		} else {
			http.NotFound(w, r)
		}
	}))
	if err != nil {
		log.Fatalf("Failed to start server, %v", err)
	}
}

func handleProvisionPOSTRequest(w http.ResponseWriter, r *http.Request) {
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
	_, err = w.Write([]byte("Message successfully enqueued for processing."))
	if err != nil {
		log.Printf("Failed to write response, %v", err)
	}
}

func handleProvisionGETRequest(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, err := w.Write([]byte("GET request received."))
	if err != nil {
		log.Printf("Failed to write response, %v", err)
	}
}
