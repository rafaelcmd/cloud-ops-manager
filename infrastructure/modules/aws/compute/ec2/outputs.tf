output "cloud_ops_manager_api_ec2_host" {
  value = aws_instance.cloud_ops_manager_api_ec2.public_ip
}

output "cloud_ops_manager_api_ec2_username" {
  value = "ec2-user"
}

output "cloud_ops_manager_api_ec2_instance_id" {
  value = aws_instance.cloud_ops_manager_api_ec2.id
}
