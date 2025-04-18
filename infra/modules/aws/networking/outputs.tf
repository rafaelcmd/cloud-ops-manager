output "cloud_ops_manager_vpc_id" {
  description = "ClodOps Manager VPC ID"
  value       = aws_vpc.cloud_ops_manager_vpc.id
}

output "cloud_ops_manager_public_subnet_id_a" {
  description = "ClodOps Manager Public subnet ID A"
  value       = aws_subnet.cloud_ops_manager_public_subnet_a.id
}

output "cloud_ops_manager_public_subnet_id_b" {
  description = "ClodOps Manager Public subnet ID B"
  value       = aws_subnet.cloud_ops_manager_public_subnet_b.id
}

output "cloud_ops_manager_private_subnet_id_a" {
  description = "ClodOps Manager Private subnet ID A"
  value       = aws_subnet.cloud_ops_manager_private_subnet_a.id
}

output "cloud_ops_manager_private_subnet_id_b" {
  description = "ClodOps Manager Private subnet ID B"
  value       = aws_subnet.cloud_ops_manager_private_subnet_b.id
}

output "rds_subnet_group" {
  description = "RDS Subnet Group"
  value       = aws_db_subnet_group.rds_subnet_group.name
}