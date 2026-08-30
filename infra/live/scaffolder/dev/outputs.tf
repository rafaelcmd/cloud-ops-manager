output "table_name" {
  description = "Name of the scaffolder's single DynamoDB table"
  value       = aws_dynamodb_table.scaffolder.name
}

output "table_arn" {
  description = "ARN of the scaffolder's single DynamoDB table"
  value       = aws_dynamodb_table.scaffolder.arn
}

output "task_queue_names" {
  description = "Per-worker queue names — the values each Deployment sets as SCAFFOLDER_TASK_QUEUE_NAME"
  value       = { for worker, queue in aws_sqs_queue.tasks : worker => queue.name }
}

output "task_queue_arns" {
  description = "Per-worker queue ARNs — the targets the scaffold state machine's .waitForTaskToken states send to"
  value       = { for worker, queue in aws_sqs_queue.tasks : worker => queue.arn }
}

output "task_dlq_arns" {
  description = "Per-worker dead-letter queue ARNs"
  value       = { for worker, queue in aws_sqs_queue.tasks_dlq : worker => queue.arn }
}

output "irsa_role_arns" {
  description = "Per-worker IRSA role ARNs. Only the github one can read the App private key."
  value       = { for worker, irsa in module.worker_irsa : worker => irsa.role_arn }
}

output "github_app_key_secret_arn" {
  description = "ARN of the secret the GitHub App's PEM private key must be put into"
  value       = aws_secretsmanager_secret.github_app_key.arn
}
