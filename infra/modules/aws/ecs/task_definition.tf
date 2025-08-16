resource "aws_ecs_task_definition" "api" {
  family                   = "resource-provisioner-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"  # Increased for Datadog Agent
  memory                   = "1024" # Increased for Datadog Agent
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  tags = {
    Datadog           = "monitored"
    "datadog:service" = "resource-provisioner-api"
    "datadog:env"     = "prod"
    "datadog:version" = "1.0.0"
    Project           = "cloudops"
    Environment       = "prod"
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
        { name = "DD_AGENT_HOST", value = "datadog-agent" },
        { name = "DD_TRACE_AGENT_PORT", value = "8126" }
      ]
      dockerLabels = {
        "com.datadoghq.ad.logs"      = "[{\"source\":\"go\",\"service\":\"resource-provisioner-api\",\"tags\":[\"env:prod\",\"project:cloudops\"]}]"
        "com.datadoghq.tags.service" = "resource-provisioner-api"
        "com.datadoghq.tags.env"     = "prod"
        "com.datadoghq.tags.version" = "1.0.0"
      }
      dependsOn = [
        {
          containerName = "datadog-agent"
          condition     = "HEALTHY"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/resource-provisioner-api"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "datadog-agent"
      image     = "public.ecr.aws/datadog/agent:7.60.0"
      essential = false
      portMappings = [
        {
          containerPort = 8125
          protocol      = "udp"
        },
        {
          containerPort = 8126
          protocol      = "tcp"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8126/info || exit 1"]
        interval     = 30
        timeout      = 5
        retries      = 3
        startPeriod  = 60
      }
      environment = [
        { name = "DD_API_KEY", value = var.datadog_api_key },
        { name = "DD_SITE", value = "datadoghq.com" },
        { name = "ECS_FARGATE", value = "true" },
        { name = "DD_DOCKER_LABELS_AS_TAGS", value = "true" },
        { name = "DD_DOGSTATSD_NON_LOCAL_TRAFFIC", value = "true" },
        { name = "DD_APM_ENABLED", value = "true" },
        { name = "DD_APM_NON_LOCAL_TRAFFIC", value = "true" },
        { name = "DD_APM_RECEIVER_SOCKET", value = "/var/run/datadog/apm.socket" },
        { name = "DD_BIND_HOST", value = "0.0.0.0" },
        { name = "DD_LOGS_ENABLED", value = "true" },
        { name = "DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL", value = "true" },
        { name = "DD_CONTAINER_EXCLUDE", value = "name:datadog-agent" },
        { name = "DD_TAGS", value = "project:cloudops,environment:prod" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/datadog-agent"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
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

  # Allow inbound traffic from ALB to application
  ingress {
    description     = "Allow inbound traffic from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  # Allow all outbound traffic for Datadog agent communication and app functionality
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "cloudops-api-ecs-sg"
    Project     = "cloudops"
    Environment = "prod"
  }
}