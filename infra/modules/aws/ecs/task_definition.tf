resource "aws_ecs_task_definition" "api" {
  family                   = "resource-provisioner-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "resource-provisioner-api"
      image     = "${data.terraform_remote_state.cloudops_manager_ecr_repository.outputs.repository_url}:latest"
      essential = true
      portMappings = [{
        containerPort = 5000
        protocol      = "tcp"
      }]
      environment = [
        { name = "DD_SERVICE",           value = "resource-provisioner-api" },
        { name = "DD_ENV",               value = "prod" },
        { name = "DD_VERSION",           value = "1.0.0" },
        { name = "DD_LOGS_ENABLED",      value = "true" },
        { name = "DD_LOGS_CONFIG",       value = "true" },
        { name = "DD_LOGS_INJECTION",    value = "true" },
        { name = "DD_LOGS_SOURCE",       value = "go" },
        { name = "DD_TAGS",              value = "project:cloudops,environment:prod" },
        { name = "DD_TRACE_AGENT_URL",   value = "http://127.0.0.1:8126" }
      ]
      logConfiguration = {
        logDriver = "awsfirelens"
        options = {
          Name       = "datadog"
          Host       = "http-intake.logs.datadoghq.com"
          TLS        = "on"
          dd_service = "provisioner_api"
          dd_source  = "ecs"
          dd_tags    = "env:prod,project:cloudops"
        }
      }
    },
    {
      name      = "datadog-agent"
      image     = "gcr.io/datadoghq/agent:7.51.0"
      essential = true
      environment = [
        { name = "DD_API_KEY",                    value = var.datadog_api_key },
        { name = "DD_ENV",                        value = "prod" },
        { name = "DD_TAGS",                       value = "project:cloudops,environment:prod" },
        { name = "ECS_FARGATE",                   value = "true" },
        { name = "DD_LOGS_ENABLED",               value = "true" },
        { name = "DD_PROCESS_AGENT_ENABLED",      value = "true" },
        { name = "DD_ENABLE_METADATA_COLLECTION", value = "true" },
        { name = "DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL", value = "false" },
        { name = "DD_CONTAINER_INCLUDE",          value = "name:resource-provisioner-api" },
        { name = "DD_CONTAINER_EXCLUDE",          value = "name:datadog-agent" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/datadog-agent"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "agent"
        }
      }
    },
    {
      name      = "log-router"
      image     = "amazon/aws-for-fluent-bit:latest"
      essential = false
      firelensConfiguration = {
        type = "fluentbit"
        options = {
          "enable-ecs-log-metadata" = "true"
        }
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/log-router"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "log-router"
        }
      }
    }
  ])

  depends_on = [
    aws_cloudwatch_log_group.ecs_api,
    aws_cloudwatch_log_group.datadog_agent,
    aws_cloudwatch_log_group.log_router
  ]
}

resource "aws_security_group" "api_ecs_task_sg" {
  name        = "cloud-ops-manager-api-ecs-sg"
  description = "Security group for CloudOps Manager ECS API"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow inbound traffic from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  ingress {
    description = "Allow Datadog agent trace injection"
    from_port   = 8126
    to_port     = 8126
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Restrict outbound traffic to HTTPS only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloudops-api-ecs-sg"
  }
}