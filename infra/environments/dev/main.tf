module "aws_networking" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/networking?ref=main"
}

module "aws_security" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/security?ref=main"

  cloud_ops_manager_vpc_id = module.aws_networking.cloud_ops_manager_vpc_id
}

module "aws_ec2" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/compute/ec2?ref=main"

  cloud_ops_manager_public_subnet_id           = module.aws_networking.cloud_ops_manager_public_subnet_id_a
  cloud_ops_manager_private_subnet_id          = module.aws_networking.cloud_ops_manager_private_subnet_id_a
  nat_gateway_id                               = module.aws_networking.nat_gateway_ready
  route_table_association_id                   = module.aws_networking.private_route_table_association_ready
  cloud_ops_manager_api_security_group_id      = module.aws_security.cloud_ops_manager_api_security_group_id
  cloud_ops_manager_consumer_security_group_id = module.aws_security.cloud_ops_manager_consumer_security_group_id
  provisioner_consumer_sqs_queue_arn           = module.aws_sqs_queue.provisioner_consumer_sqs_queue_arn
  provisioner_consumer_sqs_queue_parameter_arn = module.aws_sqs_queue.provisioner_consumer_sqs_queue_parameter_arn
  cloud_ops_manager_consumer_deploy_bucket_arn = module.s3.cloud_ops_manager_consumer_deploy_bucket_arn
}

module "aws_api_gateway" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/api-gateway?ref=main"

  cloud_ops_manager_api_host = module.aws_ec2.cloud_ops_manager_api_ec2_host
  auth_lambda_invoke_arn     = module.aws_lambda.cloud_ops_manager_api_auth_lambda_invoke_arn
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

module "rds" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/database/rds?ref=main"

  rds_subnet_group       = module.aws_networking.rds_subnet_group
  rds_security_group_ids = module.aws_security.rds_security_group_ids
  db_username            = "teste"
  db_password            = "teste12345"
}

module "s3" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/s3?ref=main"
}

module "auto_scaling" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/compute/auto-scaling?ref=main"

  cloud_ops_manager_api_security_group_id = module.aws_security.cloud_ops_manager_api_security_group_id
  cloud_ops_manager_api_public_subnet_ids = [module.aws_networking.cloud_ops_manager_public_subnet_id_a, module.aws_networking.cloud_ops_manager_public_subnet_id_b]
  cloud_ops_manager_api_tg_arn            = module.alb.cloud_ops_manager_api_tg_arn
}

module "alb" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/networking/alb?ref=main"

  cloud_ops_manager_api_public_subnet_ids = module.aws_networking.cloud_ops_manager_api_public_subnet_ids
  cloud_ops_manager_api_security_group_id = module.aws_security.cloud_ops_manager_api_security_group_id
  cloud_ops_manager_vpc_id                = module.aws_networking.cloud_ops_manager_vpc_id
}

module "cloud_watch" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/monitoring/cloud-watch?ref=main"

  cloud_ops_manager_api_autoscaling_group_name = module.auto_scaling.cloud_ops_manager_api_autoscaling_group_name
  cloud_ops_manager_api_scale_out_policy_arn   = module.auto_scaling.cloud_ops_manager_api_scale_out_policy_arn
}

module "ecs" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/compute/containers/ecs?ref=main"

  api_repository_url = module.ecr.api_repository_url
}

module "ecr" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/storage/ecr?ref=main"
}