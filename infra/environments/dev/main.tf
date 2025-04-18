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
  cloud_ops_manager_security_group_id          = module.aws_security.cloud_ops_manager_security_group_id
  provisioner_consumer_sqs_queue_arn           = module.aws_sqs_queue.provisioner_consumer_sqs_queue_arn
  provisioner_consumer_sqs_queue_parameter_arn = module.aws_sqs_queue.provisioner_consumer_sqs_queue_parameter_arn
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
  db_password            = "teste"
}