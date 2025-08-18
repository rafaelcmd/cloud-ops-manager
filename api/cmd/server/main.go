package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"github.com/sirupsen/logrus"
	httptrace "gopkg.in/DataDog/dd-trace-go.v1/contrib/net/http"
	"gopkg.in/DataDog/dd-trace-go.v1/ddtrace/tracer"

	httpmod "github.com/rafaelcmd/cloud-ops-manager/api/internal/adapters/inbound/http"
	sqsmod "github.com/rafaelcmd/cloud-ops-manager/api/internal/adapters/outbound/sqs"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/application/service"
)

func main() {
	// Initialize structured logging
	log := logrus.New()
	log.SetFormatter(&logrus.JSONFormatter{})
	log.SetLevel(logrus.InfoLevel)

	ctx := context.Background()

	// Initialize Datadog tracer with environment variables
	tracer.Start()
	defer tracer.Stop()

	log.Info("Starting Cloud Ops Manager API")

	// Load AWS configuration
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.WithError(err).Fatal("failed to load AWS config")
	}

	// Get SQS queue URL from Parameter Store
	provisionerQueueURL, err := getQueueURL(ctx, cfg)
	if err != nil {
		log.WithError(err).Fatal("failed to get SQS queue URL")
	}

	log.WithField("queue_url", provisionerQueueURL).Info("Retrieved SQS queue URL")

	// Initialize dependencies
	sqsClient := sqs.NewFromConfig(cfg)
	publisher := sqsmod.NewResourcePublisher(sqsClient, provisionerQueueURL)
	resourceService := service.NewResourceService(publisher)
	resourceHandler := httpmod.NewResourceHandler(resourceService)

	// Setup HTTP server with Datadog tracing
	router := httpmod.NewRouter(resourceHandler)
	mux := httptrace.NewServeMux(httptrace.WithServiceName("cloud-ops-manager.api"))
	mux.Handle("/", router)

	port := getPort()
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in a goroutine
	go func() {
		log.WithField("port", port).Info("Starting API server")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.WithError(err).Fatal("failed to start server")
		}
	}()

	log.WithField("port", port).Info("API server started successfully")

	// Wait for interrupt signal to gracefully shut down the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("Shutting down server...")

	// Create a deadline to wait for
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Attempt graceful shutdown
	if err := server.Shutdown(ctx); err != nil {
		log.WithError(err).Error("Server forced to shutdown")
	}

	log.Info("Server exited")
}

func getQueueURL(ctx context.Context, cfg aws.Config) (string, error) {
	ssmClient := ssm.NewFromConfig(cfg)
	provisionerQueueParamName := "/CLOUD_OPS_MANAGER/PROVISIONER_QUEUE_URL"

	result, err := ssmClient.GetParameter(ctx, &ssm.GetParameterInput{
		Name: &provisionerQueueParamName,
	})
	if err != nil {
		return "", err
	}

	if result.Parameter == nil || result.Parameter.Value == nil {
		return "", fmt.Errorf("parameter %s not found or empty", provisionerQueueParamName)
	}

	return *result.Parameter.Value, nil
}

func getPort() string {
	port := os.Getenv("PORT")
	if port == "" {
		port = "5000"
	}
	return port
}
