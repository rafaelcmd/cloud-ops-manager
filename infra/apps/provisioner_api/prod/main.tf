data "terraform_remote_state" "shared_vpc" {
  backend = "remote"

  config = {
    organization = "cloudops-manager-org"
    workspaces = {
      name = "cloudops-shared-vpc"
    }
  }
}

module "ecs" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/ecs?ref=main"

  vpc_id             = data.terraform_remote_state.shared_vpc.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.shared_vpc.outputs.private_subnet_ids
  target_group_arn   = module.alb.target_group_arn
  alb_sg_id          = module.alb.alb_sg_id
  lb_listener        = module.alb.lb_listener
  datadog_api_key    = "d7c33c222e6c154aa77c9774a0995890"
  aws_region         = "us-east-1"
}

module "alb" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/alb?ref=main"

  alb_name = "resource-provisioner-alb"
  internal = false
  subnets  = data.terraform_remote_state.shared_vpc.outputs.public_subnet_ids

  target_group_name     = "resource-provisioner-tg"
  target_group_port     = 5000
  target_group_protocol = "HTTP"
  vpc_id                = data.terraform_remote_state.shared_vpc.outputs.vpc_id
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

module "sqs" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/sqs?ref=main"
}