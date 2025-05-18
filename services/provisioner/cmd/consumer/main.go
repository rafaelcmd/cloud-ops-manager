package main

import (
	"context"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"github.com/aws/aws-xray-sdk-go/xray"
	"log"
	"net/http"
)

func main() {
	ctx := context.Background()

	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion("us-east-1"))
	if err != nil {
		log.Fatalf("Unable to load AWS config, %v", err)
	}

	cfg.HTTPClient = xray.Client(&http.Client{})

	sqsClient := sqs.NewFromConfig(cfg)
	ssmClient := ssm.NewFromConfig(cfg)

	ssmCtx, seg := xray.BeginSegment(ctx, "GetSQSQueueURL")
	param, err := ssmClient.GetParameter(ssmCtx, &ssm.GetParameterInput{
		Name: aws.String("/CLOUD_OPS_MANAGER/SQS_QUEUE_URL"),
	})
	seg.Close(err)
	if err != nil {
		log.Fatalf("Unable to get SQS queue URL from Parameter Store, %v", err)
	}

	queueUrl := aws.ToString(param.Parameter.Value)
	if queueUrl == "" {
		log.Fatalf("SQS queue URL is empty")
	}

	log.Println("Polling messages from SQS queue:", queueUrl)

	for {
		pollCtx, pollSeg := xray.BeginSegment(ctx, "PollSQSMessages")

		output, err := sqsClient.ReceiveMessage(pollCtx, &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(queueUrl),
			MaxNumberOfMessages: 5,
			WaitTimeSeconds:     10,
		})
		pollSeg.Close(err)

		if err != nil {
			log.Printf("Failed to receive messages, %v", err)
			continue
		}

		for _, message := range output.Messages {
			processCtx, subSeg := xray.BeginSubsegment(ctx, "ProcessMessage")
			log.Printf("Received message: %s", aws.ToString(message.Body))

			// Save message data in RDS

			// Delete the message after processing
			_, err := sqsClient.DeleteMessage(processCtx, &sqs.DeleteMessageInput{
				QueueUrl:      aws.String(queueUrl),
				ReceiptHandle: message.ReceiptHandle,
			})
			if err != nil {
				log.Printf("Failed to delete message, %v", err)
			} else {
				log.Println("Message deleted successfully")
			}
			subSeg.Close(nil)
		}
	}
}
