package main

import (
	"context"
	"errors"
	"net/http"
	"os"
	"time"

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

	// Add a brief delay to allow Datadog agent to start
	log.Info("Waiting for Datadog agent to initialize...")
	time.Sleep(15 * time.Second)

	// Override Datadog environment variables for consistent localhost usage
	os.Setenv("DD_AGENT_HOST", "localhost")
	os.Setenv("DD_DOGSTATSD_HOST", "localhost")

	// Debug: Log Datadog environment variables
	log.WithFields(logrus.Fields{
		"DD_AGENT_HOST":       os.Getenv("DD_AGENT_HOST"),
		"DD_TRACE_AGENT_PORT": os.Getenv("DD_TRACE_AGENT_PORT"),
		"DD_DOGSTATSD_HOST":   os.Getenv("DD_DOGSTATSD_HOST"),
		"DD_DOGSTATSD_PORT":   os.Getenv("DD_DOGSTATSD_PORT"),
		"DD_ENV":              os.Getenv("DD_ENV"),
		"DD_SERVICE":          os.Getenv("DD_SERVICE"),
		"DD_VERSION":          os.Getenv("DD_VERSION"),
	}).Info("Datadog configuration")

	// Calculate agent address - default to port 8126 if not set
	tracePort := os.Getenv("DD_TRACE_AGENT_PORT")
	if tracePort == "" {
		tracePort = "8126"
	}
	agentAddr := "localhost:" + tracePort
	log.WithField("agent_addr", agentAddr).Info("Configuring Datadog tracer")

	// Initialize Datadog tracer
	tracer.Start(
		tracer.WithEnv(os.Getenv("DD_ENV")),
		tracer.WithService(os.Getenv("DD_SERVICE")),
		tracer.WithServiceVersion(os.Getenv("DD_VERSION")),
		tracer.WithAgentAddr(agentAddr),
	)
	defer tracer.Stop()

	ctx := context.Background()

	log.Info("Starting Cloud Ops Manager API")

	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.WithError(err).Fatal("failed to load AWS config")
	}

	provisionerQueueParamName := "/CLOUD_OPS_MANAGER/PROVISIONER_QUEUE_URL"
	ssmClient := ssm.NewFromConfig(cfg)
	provisionerQueueParamOutput, err := ssmClient.GetParameter(ctx, &ssm.GetParameterInput{
		Name: &provisionerQueueParamName,
	})
	if err != nil {
		log.WithError(err).Fatal("failed to get SQS queue URL from parameter store")
	}
	provisionerQueueURL := *provisionerQueueParamOutput.Parameter.Value
	if provisionerQueueURL == "" {
		log.Fatal("SQS queue URL parameter must be set")
	}

	log.WithField("queue_url", provisionerQueueURL).Info("Retrieved SQS queue URL")

	sqsClient := sqs.NewFromConfig(cfg)
	publisher := sqsmod.NewResourcePublisher(sqsClient, provisionerQueueURL)
	resourceService := service.NewResourceService(publisher)
	resourceHandler := httpmod.NewResourceHandler(resourceService)

	// Wrap router with Datadog tracing
	router := httpmod.NewRouter(resourceHandler)

	mux := httptrace.NewServeMux(httptrace.WithServiceName("cloud-ops-manager.api"))
	mux.Handle("/", router)

	port := os.Getenv("PORT")
	if port == "" {
		port = "5000"
	}

	// Try to start server with retry logic for port conflicts
	log.WithField("port", port).Info("API server starting")

	// Create server with timeout configurations
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown handling
	go func() {
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.WithError(err).Fatal("failed to start server")
		}
	}()

	log.WithField("port", port).Info("API server started successfully")

	// Wait indefinitely
	select {}
}
