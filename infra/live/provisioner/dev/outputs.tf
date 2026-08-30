output "irsa_role_arn" {
  description = "ARN of the IAM role the provisioner pod assumes"
  value       = module.irsa.role_arn
}

output "service_account_name" {
  description = "ServiceAccount the provisioner Deployment binds to (k8s/provisioner/deployment.yaml)"
  value       = module.irsa.service_account_name
}
