module "aws_networking" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/networking?ref=main"
  environment = var.environment
}

module "aws_security" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/security?ref=main"
  environment = var.environment
  vpc_id = module.aws_networking.vpc_id
  private_key = module.aws_ec2.private_key
}

module "aws_ec2" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/compute/ec2?ref=main"
  environment = var.environment
  public_subnet_id = module.aws_networking.public_subnet_id
  security_group_id = module.aws_security.security_group_id
}