output "sqs_queue_arn" {
  description = "SQS Queue ARN for the Resource Provisioner"
  value = aws_sqs_queue.resource_provisioner_queue.arn
}