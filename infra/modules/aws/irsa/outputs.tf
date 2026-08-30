output "role_arn" {
  description = "ARN of the IAM role, for the annotation and for policies that reference the principal"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "policy_arn" {
  description = "ARN of the managed policy created from policy_json, or null when none was requested"
  value       = one(aws_iam_policy.this[*].arn)
}

output "service_account_name" {
  description = "Name of the ServiceAccount bound to the role"
  value       = var.service_account_name
}

output "service_account_namespace" {
  description = "Namespace of the ServiceAccount bound to the role"
  value       = var.namespace
}
