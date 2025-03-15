output "resource_provisioner_api_host" {
  value = aws_instance.resource-provisioner-api.public_ip
}

output "resource_provisioner_api_username" {
  value = "ec2-user"
}

output "resource_provisioner_api_private_key" {
  description = "The private key for SSH access"
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}