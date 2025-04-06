output "sqs_queue_arn" {
  description = "SQS Queue ARN for the Resource Provisioner"
  value       = aws_sqs_queue.resource_provisioner_queue.arn
}

output "sqs_queue_url" {
  description = "SQS Queue URL for the Resource Provisioner"
  value       = aws_sqs_queue.resource_provisioner_queue.url
}

output "sqs_queue_parameter_arn" {
  value = aws_ssm_parameter.resource_provisioner_api_sqs_queue_url.arn
}