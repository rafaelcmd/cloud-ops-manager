output "provisioner_queue_arn" {
  description = "SQS Queue ARN for the Resource Provisioner"
  value       = aws_sqs_queue.provisioner_queue.arn
}

output "provisioner_queue_url" {
  description = "SQS Queue URL for the Resource Provisioner"
  value       = aws_sqs_queue.provisioner_queue.url
}

output "provisioner_queue_parameter_arn" {
  value = aws_ssm_parameter.provisioner_consumer_sqs_queue_url.arn
}