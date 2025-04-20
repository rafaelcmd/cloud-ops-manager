output "cloud_ops_manager_api_security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.cloud_ops_manager_api_sg.id
}

output "cloud_ops_manager_consumer_security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.cloud_ops_manager_consumer_sg.id
}

output "rds_security_group_ids" {
  description = "RDS Security Group IDs"
  value       = [aws_security_group.rds_sg.id]
}