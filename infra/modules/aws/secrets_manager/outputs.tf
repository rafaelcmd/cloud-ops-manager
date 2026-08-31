output "secret_arn" {
  description = "ARN of the secret, for the IAM policy that grants secretsmanager:GetSecretValue"
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_name" {
  description = "Name of the secret, which is what put-secret-value takes as --secret-id"
  value       = aws_secretsmanager_secret.this.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key, for the kms:Decrypt grant a reader also needs"
  value       = aws_kms_key.this.arn
}
