resource "aws_ecs_cluster" "cloudops_cluster" {
  name = "cloudops-manager-cluster"

  tags = {
    Datadog           = "monitored"
    "datadog:service" = "cloudops-manager"
    "datadog:env"     = "prod"
    Project           = "cloudops"
    Environment       = "prod"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsAppTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "ecs_task_policy" {
  name = "ecsAppPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "sqs:GetQueueUrl",
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "logs:*",
          "cloudwatch:*",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

# CloudWatch Log Groups for ECS tasks
resource "aws_cloudwatch_log_group" "ecs_api" {
  name              = "/ecs/resource-provisioner-api"
  retention_in_days = 7

  tags = {
    Project     = "cloudops"
    Environment = "prod"
  }
}

resource "aws_cloudwatch_log_group" "datadog_agent" {
  name              = "/ecs/datadog-agent"
  retention_in_days = 7

  tags = {
    Project     = "cloudops"
    Environment = "prod"
  }
}

# CloudWatch Log Subscription Filters to forward logs to Datadog
resource "aws_cloudwatch_log_subscription_filter" "api_logs_to_datadog" {
  name            = "api-logs-to-datadog"
  log_group_name  = aws_cloudwatch_log_group.ecs_api.name
  filter_pattern  = ""
  destination_arn = var.datadog_forwarder_arn

  depends_on = [aws_cloudwatch_log_group.ecs_api]
}

resource "aws_cloudwatch_log_subscription_filter" "agent_logs_to_datadog" {
  name            = "agent-logs-to-datadog"
  log_group_name  = aws_cloudwatch_log_group.datadog_agent.name
  filter_pattern  = ""
  destination_arn = var.datadog_forwarder_arn

  depends_on = [aws_cloudwatch_log_group.datadog_agent]
}