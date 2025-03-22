module "aws_networking" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/networking?ref=main"
}

module "aws_security" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/security?ref=main"
  vpc_id = module.aws_networking.vpc_id
}

module "aws_ec2" {
  source            = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/compute/ec2?ref=main"
  public_subnet_id  = module.aws_networking.public_subnet_id
  security_group_id = module.aws_security.security_group_id
}

output "resource_provisioner_api_host" {
  value = module.aws_ec2.resource_provisioner_api_host
}

output "resource_provisioner_api_username" {
  value = module.aws_ec2.resource_provisioner_api_username
}