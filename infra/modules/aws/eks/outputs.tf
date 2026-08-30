output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA cert for the EKS API server"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group attached to the cluster control plane ENIs"
  value       = aws_security_group.cluster.id
}

output "cluster_primary_security_group_id" {
  description = "EKS-managed security group automatically attached to pods and nodes — use this in ingress rules from peers (e.g. ElastiCache) to allow traffic from the cluster"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA — consumers attach this when minting workload roles"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL (without https://) for IRSA trust policies"
  value       = replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")
}

output "fargate_pod_execution_role_arn" {
  description = "ARN of the role pods running on Fargate assume"
  value       = aws_iam_role.fargate.arn
}

output "fargate_pod_log_group_name" {
  description = "Name of the CloudWatch log group receiving Fargate pod logs (only when enable_fargate_logging is true)"
  value       = var.enable_fargate_logging ? aws_cloudwatch_log_group.fargate_pods[0].name : null
}

output "fargate_pod_log_group_arn" {
  description = "ARN of the CloudWatch log group receiving Fargate pod logs (only when enable_fargate_logging is true)"
  value       = var.enable_fargate_logging ? aws_cloudwatch_log_group.fargate_pods[0].arn : null
}

output "otel_collector_role_arn" {
  description = "ARN of the OTel Collector's IRSA role (only when install_otel_collector is true). Annotated onto the Terraform-managed ServiceAccount."
  value       = one(module.otel_collector_irsa[*].role_arn)
}
