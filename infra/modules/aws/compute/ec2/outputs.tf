output "cloud_ops_manager_api_ec2_host" {
  value = aws_instance.cloud_ops_manager_api_ec2.public_ip
}
