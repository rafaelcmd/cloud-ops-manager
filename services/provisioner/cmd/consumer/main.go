package main

import (
	"context"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/ssm"
	"log"
)

func main() {
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion("us-east-1"))
	if err != nil {
		log.Fatalf("Unable to load AWS config, %v", err)
	}

	sqsClient := sqs.NewFromConfig(cfg)
	ssmClient := ssm.NewFromConfig(cfg)

	param, err := ssmClient.GetParameter(context.TODO(), &ssm.GetParameterInput{
		Name: aws.String("/CLOUD_OPS_MANAGER/SQS_QUEUE_URL"),
	})
	if err != nil {
		log.Fatalf("Unable to get SQS queue URL from Parameter Store, %v", err)
	}

	queueUrl := *param.Parameter.Value
	if queueUrl == "" {
		log.Fatalf("SQS queue URL is empty")
	}

	log.Println("Polling messages from SQS queue:", queueUrl)

	for {
		output, err := sqsClient.ReceiveMessage(context.TODO(), &sqs.ReceiveMessageInput{
			QueueUrl:            aws.String(queueUrl),
			MaxNumberOfMessages: 5,
			WaitTimeSeconds:     10,
		})

		if err != nil {
			log.Printf("Failed to receive messages, %v", err)
			continue
		}

		for _, message := range output.Messages {
			log.Printf("Received message: %s", aws.ToString(message.Body))

			// Save message data in Postgres

			// Delete the message after processing
			_, err := sqsClient.DeleteMessage(context.TODO(), &sqs.DeleteMessageInput{
				QueueUrl:      aws.String(queueUrl),
				ReceiptHandle: message.ReceiptHandle,
			})
			if err != nil {
				log.Printf("Failed to delete message, %v", err)
			} else {
				log.Println("Message deleted successfully")
			}
		}
	}
}
