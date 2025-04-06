output "vpc_id" {
  description = "ClodOps Manager VPC ID"
  value       = aws_vpc.cloud_ops_manager_vpc.id
}

output "public_subnet_id" {
  description = "ClodOps Manager Public subnet ID"
  value       = aws_subnet.cloud_ops_manager_public_subnet.id
}