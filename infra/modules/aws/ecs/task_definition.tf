resource "aws_ecs_task_definition" "api" {
  family                   = var.task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  tags = merge(var.tags, {
    Datadog           = "monitored"
    "datadog:service" = var.service_name
    "datadog:env"     = var.environment
    "datadog:version" = var.app_version
    Project           = var.project
    Environment       = var.environment
  })

  container_definitions = jsonencode([
    {
      name      = var.app_container_name
      image     = var.app_image_uri
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      environment = [
        { name = "DD_SERVICE", value = var.service_name },
        { name = "DD_ENV", value = var.environment },
        { name = "DD_VERSION", value = var.app_version },
        { name = "DD_LOGS_ENABLED", value = "true" },
        { name = "DD_LOGS_INJECTION", value = "true" },
        { name = "DD_LOGS_SOURCE", value = "go" },
        { name = "DD_TAGS", value = "project:${var.project},environment:${var.environment},service:${var.service_name}" },
        { name = "DD_AGENT_HOST", value = "localhost" },
        { name = "DD_TRACE_AGENT_PORT", value = "8126" },
        { name = "DD_DOGSTATSD_PORT", value = "8125" }
      ]
      dockerLabels = {
        "com.datadoghq.ad.logs"      = "[{\"source\":\"go\",\"service\":\"${var.service_name}\",\"tags\":[\"env:${var.environment}\",\"project:${var.project}\"]}]"
        "com.datadoghq.tags.service" = var.service_name
        "com.datadoghq.tags.env"     = var.environment
        "com.datadoghq.tags.version" = var.app_version
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.app_log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "datadog-agent"
      image     = var.datadog_agent_image
      essential = true
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
        { name = "DD_SITE", value = var.datadog_site },
        { name = "ECS_FARGATE", value = "true" },
        { name = "DD_DOCKER_LABELS_AS_TAGS", value = "true" },
        { name = "DD_DOGSTATSD_NON_LOCAL_TRAFFIC", value = "true" },
        { name = "DD_APM_ENABLED", value = "true" },
        { name = "DD_APM_NON_LOCAL_TRAFFIC", value = "true" },
        { name = "DD_BIND_HOST", value = "0.0.0.0" },
        { name = "DD_LOGS_ENABLED", value = "true" },
        { name = "DD_LOGS_CONFIG_USE_HTTP", value = "true" },
        { name = "DD_LOGS_CONFIG_USE_COMPRESSION", value = "true" },
        { name = "DD_HOSTNAME", value = "${var.service_name}-${var.environment}" },
        { name = "DD_CLUSTER_NAME", value = var.cluster_name },
        { name = "DD_TAGS", value = "project:${var.project},environment:${var.environment},cluster:${var.cluster_name}" },
        { name = "DD_ECS_TASK_COLLECTION_ENABLED", value = "true" },
        { name = "DD_CONTAINER_LABELS_AS_TAGS", value = "{\"com.datadoghq.tags.service\":\"service\",\"com.datadoghq.tags.env\":\"env\",\"com.datadoghq.tags.version\":\"version\"}" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.datadog_log_group_name
          "awslogs-region"        = var.aws_region
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
  name        = var.security_group_name
  description = var.security_group_description
  vpc_id      = var.vpc_id

  # Allow inbound traffic from ALB to application
  ingress {
    description     = "Allow inbound traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
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

  tags = merge(var.tags, {
    Name        = "cloudops-api-ecs-sg"
    Project     = var.project
    Environment = var.environment
  })
}