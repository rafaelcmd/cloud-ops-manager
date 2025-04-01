output "cloud_ops_manager_api_host" {
  value = module.aws_ec2.resource_provisioner_api_host
}

output "cloud_ops_manager_api_username" {
  value = module.aws_ec2.resource_provisioner_api_username
}

output "cloud_ops_manager_api_instance_id" {
  value = module.aws_ec2.resource_provisioner_api_instance_id
}