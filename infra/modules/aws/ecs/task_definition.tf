resource "aws_ecs_task_definition" "api" {
  family                   = "resource-provisioner-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  tags = {
    Datadog                = "monitored"
    "datadog:service"      = "resource-provisioner-api"
    "datadog:env"          = "prod"
    "datadog:version"      = "1.0.0"
    Project                = "cloudops"
    Environment            = "prod"
  }

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
        { name = "DD_SERVICE", value = "resource-provisioner-api" },
        { name = "DD_ENV", value = "prod" },
        { name = "DD_VERSION", value = "1.0.0" },
        { name = "DD_LOGS_ENABLED", value = "true" },
        { name = "DD_LOGS_INJECTION", value = "true" },
        { name = "DD_LOGS_SOURCE", value = "go" },
        { name = "DD_TAGS", value = "project:cloudops,environment:prod,service:resource-provisioner-api" },
        { name = "DD_AGENT_HOST", value = "localhost" },
        { name = "DD_TRACE_AGENT_PORT", value = "8126" },
        { name = "DD_API_KEY", value = var.datadog_api_key }
      ]
      dockerLabels = {
        "com.datadoghq.ad.logs" = "[{\"source\":\"go\",\"service\":\"resource-provisioner-api\",\"tags\":[\"env:prod\",\"project:cloudops\"]}]"
        "com.datadoghq.tags.service" = "resource-provisioner-api"
        "com.datadoghq.tags.env" = "prod"
        "com.datadoghq.tags.version" = "1.0.0"
      }
      dependsOn = [
        {
          containerName = "datadog-agent"
          condition     = "START"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/resource-provisioner-api"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
    },
    {
      name      = "datadog-agent"
      image     = "gcr.io/datadoghq/agent:7.60.0"
      essential = true
      portMappings = [
        {
          containerPort = 8126
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "DD_API_KEY", value = var.datadog_api_key },
        { name = "DD_ENV", value = "prod" },
        { name = "DD_SERVICE", value = "datadog-agent" },
        { name = "DD_TAGS", value = "project:cloudops,environment:prod" },
        { name = "ECS_FARGATE", value = "true" },
        { name = "DD_LOGS_ENABLED", value = "true" },
        { name = "DD_PROCESS_AGENT_ENABLED", value = "true" },
        { name = "DD_ENABLE_METADATA_COLLECTION", value = "true" },
        { name = "DD_ECS_TASK_COLLECTION_ENABLED", value = "true" },
        { name = "DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL", value = "true" },
        { name = "DD_LOGS_CONFIG_AUTO_MULTI_LINE_DETECTION", value = "true" },
        { name = "DD_LOGS_CONFIG_DOCKER_LABELS_AS_TAGS", value = "true" },
        { name = "DD_CONTAINER_INCLUDE", value = "name:resource-provisioner-api" },
        { name = "DD_CONTAINER_EXCLUDE", value = "name:datadog-agent" },
        { name = "DD_APM_ENABLED", value = "true" },
        { name = "DD_APM_NON_LOCAL_TRAFFIC", value = "true" },
        { name = "DD_DOGSTATSD_NON_LOCAL_TRAFFIC", value = "true" },
        { name = "DD_CONTAINER_LABELS_AS_TAGS", value = "{\"com.datadoghq.tags.service\":\"service\",\"com.datadoghq.tags.env\":\"env\",\"com.datadoghq.tags.version\":\"version\"}" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/datadog-agent"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "agent"
        }
      }
    }
  ])

  depends_on = [
    aws_cloudwatch_log_group.ecs_api,
    aws_cloudwatch_log_group.datadog_agent
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