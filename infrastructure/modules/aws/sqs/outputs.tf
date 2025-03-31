output "sqs_queue_arn" {
  description = "SQS Queue ARN for the Resource Provisioner"
  value = aws_sqs_queue.resource_provisioner_queue.arn
}

output "sqs_queue_url" {
  description = "SQS Queue URL for the Resource Provisioner"
  value = aws_sqs_queue.resource_provisioner_queue.url
}