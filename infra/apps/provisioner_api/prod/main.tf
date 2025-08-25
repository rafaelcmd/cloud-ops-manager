module "ecs" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/ecs?ref=main"

  # Infrastructure dependencies
  vpc_id             = data.terraform_remote_state.shared_vpc.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.shared_vpc.outputs.private_subnet_ids
  target_group_arn   = module.alb.target_group_arn
  alb_sg_id          = module.alb.alb_sg_id
  lb_listener        = module.alb.lb_listener
  forwarder_arn      = module.datadog_forwarder.datadog_forwarder_arn

  # Basic configuration
  datadog_api_key = var.datadog_api_key
  aws_region      = var.aws_region
  environment     = var.environment
  project         = var.project
  service_name    = var.service_name
  app_version     = var.app_version

  # ECS-specific configuration
  cluster_name        = var.cluster_name
  task_family         = var.task_family
  task_cpu            = var.task_cpu
  task_memory         = var.task_memory
  desired_count       = var.desired_count
  container_port      = var.container_port
  app_container_name  = var.service_name
  datadog_agent_image = var.datadog_agent_image
  datadog_site        = "datadoghq.com"

  # IAM role names
  task_execution_role_name = "${var.project}-${var.environment}-ecsTaskExecutionRole"
  task_role_name           = "${var.project}-${var.environment}-ecsTaskRole"
  task_policy_name         = "${var.project}-${var.environment}-ecsAppPolicy"

  # Deployment configuration
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  platform_version                   = var.platform_version
  force_new_deployment               = var.force_new_deployment
  assign_public_ip                   = var.assign_public_ip

  # Logging configuration
  log_retention_days     = 7
  app_log_group_name     = "/ecs/${var.service_name}"
  datadog_log_group_name = "/ecs/datadog-agent"

  # Security group configuration
  security_group_name        = "${var.project}-${var.environment}-api-ecs-sg"
  security_group_description = "Security group for ${var.project} ECS API"

  # Application image configuration
  app_image_uri = "${data.terraform_remote_state.cloudops_manager_ecr_repository.outputs.repository_url}:${var.app_image_tag}"

  # Common tags
  tags = {
    Environment = var.environment
    Project     = var.project
    Service     = var.service_name
  }
}

module "alb" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/alb?ref=main"

  # ALB configuration
  alb_name           = var.alb_name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  subnets            = data.terraform_remote_state.shared_vpc.outputs.public_subnet_ids

  # Target group configuration
  target_group_name     = var.target_group_name
  target_group_port     = var.container_port
  target_group_protocol = var.target_group_protocol
  vpc_id                = data.terraform_remote_state.shared_vpc.outputs.vpc_id
  target_type           = var.target_type

  # Health check configuration
  health_check_path     = var.health_check_path
  health_check_interval = var.health_check_interval
  health_check_timeout  = var.health_check_timeout
  healthy_threshold     = var.healthy_threshold
  unhealthy_threshold   = var.unhealthy_threshold
  matcher               = var.matcher

  # Listener configuration
  listener_port       = var.listener_port
  listener_protocol   = var.listener_protocol
  default_action_type = var.default_action_type

  # Security group configuration
  security_group_name        = var.security_group_name
  security_group_description = var.security_group_description
  ingress_from_port          = var.ingress_from_port
  ingress_to_port            = var.ingress_to_port
  ingress_protocol           = var.ingress_protocol
  ingress_cidr_blocks        = var.ingress_cidr_blocks
  egress_from_port           = var.egress_from_port
  egress_to_port             = var.egress_to_port
  egress_protocol            = var.egress_protocol
  egress_cidr_blocks         = var.egress_cidr_blocks

  # Common configuration
  project     = var.project
  environment = var.environment

  tags = {
    Environment = var.environment
    Project     = var.project
    Service     = var.service_name
  }
}

module "sqs" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/sqs?ref=main"

  # SQS configuration
  queue_name                = var.queue_name
  delay_seconds             = var.delay_seconds
  max_message_size          = var.max_message_size
  message_retention_seconds = var.message_retention_seconds
  receive_wait_time_seconds = var.receive_wait_time_seconds

  # SSM parameter configuration
  ssm_parameter_name = var.ssm_parameter_name
  ssm_parameter_type = var.ssm_parameter_type

  # Common tags
  tags = {
    Environment = var.environment
    Project     = var.project
    Service     = var.service_name
  }
}

# Datadog Lambda Forwarder for collecting application logs (required for ECS Fargate)
module "datadog_forwarder" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/lambda?ref=main"

  function_name = var.lambda_function_name
  source_dir    = "${path.module}/lambda-src"
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  environment_variables = {
    DD_API_KEY = var.datadog_api_key
    DD_SITE    = "datadoghq.com"
    DD_SOURCE  = "aws"
    DD_TAGS    = "env:${var.environment},project:${var.project},service:${var.service_name}"
  }

  # Explicitly set to -1 to not reserve any concurrency
  reserved_concurrent_executions = -1

  tags = {
    Environment = var.environment
    Project     = var.project
    Service     = var.service_name
  }

  log_retention_days = 7

  # Enable CloudWatch Logs invocation
  allow_cloudwatch_logs_invocation = true

  # Additional IAM policy for Datadog forwarder
  additional_inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}
