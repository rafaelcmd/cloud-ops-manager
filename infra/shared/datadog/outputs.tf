# =============================================================================
# DATADOG AWS INTEGRATION OUTPUTS
# Outputs for Datadog AWS integration role and authentication
# =============================================================================

output "datadog_integration_role_arn" {
  description = "ARN of the Datadog integration IAM role"
  value       = aws_iam_role.datadog_integration_role.arn
}

output "datadog_integration_external_id" {
  description = "External ID for Datadog integration"
  value       = var.external_id
  sensitive   = true
}
