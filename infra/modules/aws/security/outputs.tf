output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.cloud_ops_manager_api_sg.id
}