module "aws_networking" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/networking?ref=main"
}

module "aws_security" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/security?ref=main"

  vpc_id = module.aws_networking.vpc_id
}

module "aws_ec2" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/compute/ec2?ref=main"

  public_subnet_id  = module.aws_networking.public_subnet_id
  security_group_id = module.aws_security.security_group_id
}

module "aws_api_gateway" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/api-gateway?ref=main"

  resource_provisioner_api_host = module.aws_ec2.resource_provisioner_api_host
  aws_region                    = "us-east-1"
  stage_name                    = "dev"
}

module "aws_sqs_queue" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/sqs?ref=main"
}

output "resource_provisioner_api_host" {
  value = module.aws_ec2.resource_provisioner_api_host
}

output "resource_provisioner_api_username" {
  value = module.aws_ec2.resource_provisioner_api_username
}

output "resource_provisioner_api_instance_id" {
  value = module.aws_ec2.resource_provisioner_api_instance_id
}

output "resource_provisioner_api_url" {
  description = "Public Invoke URL of the Resource Provisioner API Gateway"
  value       = module.aws_api_gateway.api_invoke_url
}