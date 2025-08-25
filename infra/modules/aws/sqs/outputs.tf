# =============================================================================
# SQS MODULE OUTPUTS
# Outputs for SQS queue resources
# =============================================================================

output "queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.provisioner_queue.arn
}

output "queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.provisioner_queue.url
}

output "queue_name" {
  description = "Name of the SQS queue"
  value       = aws_sqs_queue.provisioner_queue.name
}

output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter storing the queue URL"
  value       = aws_ssm_parameter.provisioner_queue_url.arn
}

output "ssm_parameter_name" {
  description = "Name of the SSM parameter storing the queue URL"
  value       = aws_ssm_parameter.provisioner_queue_url.name
}
