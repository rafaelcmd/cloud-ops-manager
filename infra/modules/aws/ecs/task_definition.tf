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
        { name = "DD_AGENT_HOST", value = "localhost" },
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
          condition     = "START"
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
      environment = [
        { name = "DD_API_KEY", value = var.datadog_api_key },
        { name = "DD_SITE", value = "datadoghq.com" },
        { name = "ECS_FARGATE", value = "true" },
        { name = "DD_DOCKER_LABELS_AS_TAGS", value = "true" },
        { name = "DD_DOGSTATSD_NON_LOCAL_TRAFFIC", value = "true" },
        { name = "DD_APM_ENABLED", value = "true" },
        { name = "DD_APM_NON_LOCAL_TRAFFIC", value = "true" },
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

  ingress {
    description     = "Allow inbound traffic from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  # Datadog Agent APM traces (TCP)
  ingress {
    description = "Allow Datadog agent APM traces"
    from_port   = 8126
    to_port     = 8126
    protocol    = "tcp"
    self        = true
  }

  # Datadog Agent DogStatsD metrics (UDP)
  ingress {
    description = "Allow Datadog agent DogStatsD metrics"
    from_port   = 8125
    to_port     = 8125
    protocol    = "udp"
    self        = true
  }

  # HTTPS outbound for Datadog agent communication
  egress {
    description = "Allow HTTPS outbound for Datadog agent"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP outbound for package updates and health checks
  egress {
    description = "Allow HTTP outbound for updates"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DNS resolution (UDP)
  egress {
    description = "Allow DNS resolution UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DNS resolution (TCP)
  egress {
    description = "Allow DNS resolution TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloudops-api-ecs-sg"
    Project = "cloudops"
    Environment = "prod"
  }
}