module "shared_vpc" {
  source               = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/shared/aws/vpc?ref=main"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]
  project              = "cloudops"
  environment          = "prod"
  tags = {
    Owner      = "platform-team"
    CostCenter = "cloudops-prod"
  }
}

module "ecs" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/cloudops_api/aws/ecs?ref=main"
}

module "alb_resource_provisioner_api" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/cloudops_api/aws/alb?ref=main"
}