output "datadog_integration_role_arn" {
  description = "ARN of the Datadog integration IAM role"
  value       = module.aws_integration.role_arn
}

output "datadog_integration_external_id" {
  description = "Datadog-generated External ID pinned in the integration role's trust policy"
  value       = datadog_integration_aws_account.this.auth_config.aws_auth_config_role.external_id
  sensitive   = true
}
