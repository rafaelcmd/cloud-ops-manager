output "resource_provisioner_api_host" {
  value = aws_instance.resource-provisioner-api.public_ip
}

output "resource_provisioner_api_username" {
  value = "ec2-user"
}