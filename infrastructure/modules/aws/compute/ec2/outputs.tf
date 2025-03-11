output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.resource-provisioner-api.id
}

output "private_key" {
  description = "The private key for SSH access"
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}