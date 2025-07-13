package main

import (
	"context"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	httpmod "github.com/rafaelcmd/cloud-ops-manager/api/internal/adapters/inbound/http"
	sqsmod "github.com/rafaelcmd/cloud-ops-manager/api/internal/adapters/outbound/sqs"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/application/service"
	"log"
	"net/http"
	"os"
)

func main() {
	ctx := context.Background()

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatalf("failed to load AWS config: %v", err)
	}

	provisionerQueueParamName := "/CLOUD_OPS_MANAGER/PROVISIONER_QUEUE_URL"
	ssmClient := ssm.NewFromConfig(cfg)
	provisionerQueueParamOutput, err := ssmClient.GetParameter(ctx, &ssm.GetParameterInput{
		Name: &provisionerQueueParamName,
	})
	if err != nil {
		log.Fatalf("failed to get SQS queue URL from parameter store: %v", err)
	}
	provisionerQueueURL := *provisionerQueueParamOutput.Parameter.Value
	if provisionerQueueURL == "" {
		log.Fatal("SQS queue URL parameter must be set")
	}

	sqsClient := sqs.NewFromConfig(cfg)
	publisher := sqsmod.NewResourcePublisher(sqsClient, provisionerQueueURL)
	resourceService := service.NewResourceService(publisher)
	resourceHandler := httpmod.NewResourceHandler(resourceService)

	router := httpmod.NewRouter(resourceHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "5000"
	}

	log.Printf("API running on http://localhost:%s", port)
	if err := http.ListenAndServe(":"+port, router); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}
