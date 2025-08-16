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
  datadog_api_key    = var.datadog_api_key
  aws_region         = "us-east-1"
  forwarder_arn      = module.datadog_forwarder.forwarder_arn
}

module "alb" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/alb?ref=main"

  alb_name           = "resource-provisioner-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.terraform_remote_state.shared_vpc.outputs.public_subnet_ids

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

# Datadog Lambda Forwarder for collecting application logs
module "datadog_forwarder" {
  source = "git::https://github.com/rafaelcmd/cloud-ops-manager.git//infra/modules/aws/lambda?ref=main"

  function_name = "provisioner-api-datadog-forwarder"
  source_dir    = "${path.module}/lambda-src"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 120
  memory_size   = 1024

  environment_variables = {
    DD_API_KEY = var.datadog_api_key
    DD_SITE    = "datadoghq.com"
    DD_SOURCE  = "aws"
    DD_TAGS    = "env:${var.environment},project:${var.project},service:provisioner-api"
  }

  # Explicitly set to -1 to not reserve any concurrency
  reserved_concurrent_executions = -1

  tags = {
    Environment = var.environment
    Project     = var.project
    Service     = "provisioner-api"
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
