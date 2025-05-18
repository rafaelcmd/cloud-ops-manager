package main

import (
	"context"
	"encoding/json"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"github.com/aws/aws-xray-sdk-go/xray"
	"log"
	"net/http"
)

var (
	sqsClient *sqs.Client
	ssmClient *ssm.Client
	queueUrl  string
)

func main() {
	ctx, seg := xray.BeginSegment(context.Background(), "ResourceProvisionerAPI")
	defer seg.Close(nil)

	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion("us-east-1"))
	if err != nil {
		log.Fatalf("Unable to load AWS config, %v", err)
	}

	cfg.HTTPClient = xray.Client(&http.Client{})

	sqsClient = sqs.NewFromConfig(cfg)
	ssmClient = ssm.NewFromConfig(cfg)

	param, err := ssmClient.GetParameter(ctx, &ssm.GetParameterInput{
		Name: aws.String("/CLOUD_OPS_MANAGER/SQS_QUEUE_URL"),
	})
	if err != nil {
		log.Fatalf("Unable to get SQS queue URL from Parameter Store, %v", err)
	}

	queueUrl = *param.Parameter.Value

	xrayHandler := xray.Handler(xray.NewFixedSegmentNamer("resource-provisioner"), http.HandlerFunc(router))
	log.Println("Server running on port 5000")
	log.Fatal(http.ListenAndServe(":5000", xrayHandler))
}

func router(w http.ResponseWriter, r *http.Request) {
	switch {
	case r.URL.Path == "/resource-provisioner" && r.Method == http.MethodPost:
		handleProvisionPOSTRequest(w, r)
	case r.URL.Path == "/resource-provisioner" && r.Method == http.MethodGet:
		handleProvisionGETRequest(w, r)
	default:
		http.NotFound(w, r)
	}
}

func handleProvisionPOSTRequest(w http.ResponseWriter, r *http.Request) {
	log.Println("Handling POST request for resource provisioning")

	ctx := r.Context()

	payload := map[string]interface{}{
		"action":   "provision",
		"resource": "ec2",
		"source":   "cloudops-manager",
	}

	body, err := json.Marshal(payload)
	if err != nil {
		http.Error(w, "Failed to marshal request body", http.StatusInternalServerError)
		return
	}

	_, err = sqsClient.SendMessage(ctx, &sqs.SendMessageInput{
		QueueUrl:    aws.String(queueUrl),
		MessageBody: aws.String(string(body)),
	})
	if err != nil {
		http.Error(w, "Failed to send message to SQS", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusAccepted)
	w.Write([]byte("Resource provisioning request accepted"))
	log.Println("Resource provisioning request sent to SQS")
}

func handleProvisionGETRequest(w http.ResponseWriter, r *http.Request) {
	log.Println("Received GET request")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("GET request received."))
}
