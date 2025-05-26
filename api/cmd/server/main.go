package main

import (
	"context"
	"encoding/json"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
	"go.opentelemetry.io/otel/trace"
	"log"
	"net/http"
	"os"
)

var (
	sqsClient *sqs.Client
	ssmClient *ssm.Client
	queueUrl  string
	tracer    trace.Tracer
)

func main() {
	ctx := context.Background()

	shutdown := initTracer(ctx)
	defer shutdown()

	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion("us-east-1"))
	if err != nil {
		log.Fatalf("Unable to load AWS config, %v", err)
	}

	sqsClient = sqs.NewFromConfig(cfg)
	ssmClient = ssm.NewFromConfig(cfg)

	param, err := ssmClient.GetParameter(ctx, &ssm.GetParameterInput{
		Name: aws.String("/CLOUD_OPS_MANAGER/SQS_QUEUE_URL"),
	})
	if err != nil {
		log.Fatalf("Unable to get SQS queue URL from Parameter Store, %v", err)
	}

	queueUrl = *param.Parameter.Value

	http.HandleFunc("/resource-provisioner", router)
	log.Fatal(http.ListenAndServe(":5000", nil))
}

func router(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "router")
	defer span.End()

	switch {
	case r.URL.Path == "/resource-provisioner" && r.Method == http.MethodPost:
		handleProvisionPOSTRequest(ctx, w, r)
	case r.URL.Path == "/resource-provisioner" && r.Method == http.MethodGet:
		handleProvisionGETRequest(ctx, w, r)
	default:
		http.NotFound(w, r)
	}
}

func handleProvisionPOSTRequest(ctx context.Context, w http.ResponseWriter, r *http.Request) {
	_, span := tracer.Start(ctx, "handleProvisionPOSTRequest")
	defer span.End()

	log.Println("Handling POST request for resource provisioning")

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

func handleProvisionGETRequest(ctx context.Context, w http.ResponseWriter, r *http.Request) {
	_, span := tracer.Start(ctx, "handleProvisionGETRequest")
	defer span.End()

	log.Println("Received GET request")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("GET request received."))
}

func initTracer(ctx context.Context) func() {
	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		endpoint = "localhost:4318"
	}

	exporter, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint(endpoint),
		otlptracehttp.WithInsecure(),
	)
	if err != nil {
		log.Fatalf("Failed to create OTLP exporter: %v", err)
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName("resource-provisioner-api"),
			attribute.String("environment", "development"),
		),
	)
	if err != nil {
		log.Fatalf("Failed to create resource: %v", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)

	otel.SetTracerProvider(tp)
	tracer = tp.Tracer("cloudops-manager/resource-provisioner-api")

	return func() {
		if err := tp.Shutdown(ctx); err != nil {
			log.Fatalf("Error shutting down tracer provider: %v", err)
		}
	}
}
