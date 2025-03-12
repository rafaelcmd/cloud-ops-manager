module "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/compute/ec2?ref=main" {
  source = "../../modules/aws/networking"
  environment = var.environment
}

module "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/networking?ref=main" {
  source = "../../modules/aws/security"
  environment = var.environment
  vpc_id = module.aws_networking.vpc_id
  private_key = module.aws_ec2.private_key
}

module "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infrastructure/modules/aws/security?ref=main" {
  source = "../../modules/aws/compute/ec2"
  environment = var.environment
  public_subnet_id = module.aws_networking.public_subnet_id
  security_group_id = module.aws_security.security_group_id
}