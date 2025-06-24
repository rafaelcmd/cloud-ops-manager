module "aws_networking" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/networking?ref=main"
}

module "aws_security" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/security?ref=main"

  cloud_ops_manager_vpc_id = module.aws_networking.cloud_ops_manager_vpc_id
}

module "aws_api_gateway" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/api-gateway?ref=main"

  auth_lambda_invoke_arn = module.aws_lambda.cloud_ops_manager_api_auth_lambda_invoke_arn
}

module "aws_sqs_queue" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/sqs?ref=main"
}

module "aws_cognito" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/cognito?ref=main"
}

module "aws_lambda" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/compute/lambda?ref=main"

  cloud_ops_manager_api_user_pool_id             = module.aws_cognito.cloud_ops_manager_api_user_pool_id
  cloud_ops_manager_api_user_pool_client_id      = module.aws_cognito.cloud_ops_manager_api_user_pool_client_id
  cloud_ops_manager_api_deployment_execution_arn = module.aws_api_gateway.cloud_ops_manager_api_deployment_execution_arn
}

module "alb" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/networking/alb?ref=main"

  cloud_ops_manager_api_public_subnet_ids = module.aws_networking.cloud_ops_manager_api_public_subnet_ids
  cloud_ops_manager_api_security_group_id = module.aws_security.cloud_ops_manager_api_security_group_id
  cloud_ops_manager_ecs_alb_sg            = module.aws_security.cloud_ops_manager_ecs_alb_security_group_id
  cloud_ops_manager_vpc_id                = module.aws_networking.cloud_ops_manager_vpc_id
}

module "ecs" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/compute/containers/ecs?ref=main"

  cloud_ops_manager_api_public_subnet_ids = module.aws_networking.cloud_ops_manager_api_public_subnet_ids
  cloud_ops_manager_ecs_task_sg           = module.aws_security.cloud_ops_manager_ecs_task_sg
  cloud_ops_manager_api_ecs_tg_arn        = module.alb.cloud_ops_manager_api_ecs_tg_arn
  cloud_ops_manager_api_ecs_listener      = module.alb.cloud_ops_manager_api_ecs_listener
}

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
