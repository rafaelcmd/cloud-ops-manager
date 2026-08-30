# =============================================================================
# EKS OUTPUTS
# Consumed by the edge stack (infra/live/api_gateway/dev) and by
# operators running kubectl against the cluster.
# =============================================================================

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider — needed when minting IRSA roles for workloads"
  value       = module.eks.oidc_provider_arn
}

output "api_nlb_arn" {
  description = "ARN of the Terraform-managed API NLB"
  value       = module.api_nlb.nlb_arn
}

output "api_nlb_dns_name" {
  description = "DNS name of the Terraform-managed API NLB"
  value       = module.api_nlb.nlb_dns_name
}

output "api_target_group_arn" {
  description = "ARN of the Terraform-managed API target group"
  value       = module.api_nlb.target_group_arn
}
