output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.resource-provisioner-api-sg.id
}