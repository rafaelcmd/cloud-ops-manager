resource "aws_ecs_cluster" "cloudops_cluster" {
  name = var.cluster_name

  tags = merge(var.tags, {
    Datadog           = "monitored"
    "datadog:service" = var.service_name
    "datadog:env"     = var.environment
    Project           = var.project
    Environment       = var.environment
  })
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = var.task_execution_role_name

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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = var.task_role_name

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

  tags = var.tags
}

resource "aws_iam_policy" "ecs_task_policy" {
  name = var.task_policy_name

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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

# CloudWatch Log Groups for ECS tasks
resource "aws_cloudwatch_log_group" "ecs_api" {
  name              = var.app_log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_cloudwatch_log_group" "datadog_agent" {
  name              = var.datadog_log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}
