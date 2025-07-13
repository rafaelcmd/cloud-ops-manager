module "shared_vpc" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/shared/aws/vpc?ref=main"

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
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/provisioner_api/aws/ecs?ref=main"

  vpc_id             = module.shared_vpc.vpc_id
  private_subnet_ids = module.shared_vpc.private_subnet_ids
  target_group_arn   = module.alb_resource_provisioner_api.target_group_arn
}

module "alb_resource_provisioner_api" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/provisioner_api/aws/alb?ref=main"

  alb_name        = "resource-provisioner-alb"
  internal        = false
  security_groups = [module.ecs.ecs_service_sg]
  subnets         = module.shared_vpc.public_subnet_ids

  target_group_name     = "resource-provisioner-tg"
  target_group_port     = 5000
  target_group_protocol = "HTTP"
  vpc_id                = module.shared_vpc.vpc_id
  target_type           = "ip"

  health_check_path     = "/health"
  health_check_interval = 30
  health_check_timeout  = 5
  healthy_threshold     = 3
  unhealthy_threshold   = 2
  matcher               = "200"

  listener_port     = 80
  listener_protocol = "HTTP"

  project     = "cloudops"
  environment = "prod"

  tags = {
    Environment = "prod"
    Project     = "cloudops"
  }
}