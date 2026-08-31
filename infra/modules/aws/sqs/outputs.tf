output "queue_arn" {
  description = "ARN of the queue, for IAM policies written against it"
  value       = aws_sqs_queue.this.arn
}

output "queue_url" {
  description = "URL of the queue, which is what the AWS SDKs take"
  value       = aws_sqs_queue.this.url
}

output "queue_name" {
  description = "Name of the queue"
  value       = aws_sqs_queue.this.name
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue, or null when enable_dlq is false"
  value       = one(aws_sqs_queue.dlq[*].arn)
}

output "dlq_url" {
  description = "URL of the dead-letter queue, or null when enable_dlq is false"
  value       = one(aws_sqs_queue.dlq[*].url)
}

output "dlq_name" {
  description = "Name of the dead-letter queue, or null when enable_dlq is false"
  value       = one(aws_sqs_queue.dlq[*].name)
}
