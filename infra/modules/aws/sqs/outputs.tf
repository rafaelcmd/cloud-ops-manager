output "provisioner_consumer_sqs_queue_arn" {
  description = "SQS Queue ARN for the Resource Provisioner"
  value       = aws_sqs_queue.resource_provisioner_sqs_queue.arn
}

output "provisioner_consumer_sqs_queue_url" {
  description = "SQS Queue URL for the Resource Provisioner"
  value       = aws_sqs_queue.resource_provisioner_sqs_queue.url
}

output "provisioner_consumer_sqs_queue_parameter_arn" {
  value = aws_ssm_parameter.provisioner_consumer_sqs_queue_url.arn
}