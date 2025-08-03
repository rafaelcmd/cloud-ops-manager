resource "datadog_integration_aws_account" "this" {
  account_tags   = ["env:prod"]
  aws_account_id = var.aws_account_id
  aws_partition  = var.aws_partition

  aws_regions {
    include_all = true
  }

  auth_config {
    aws_auth_config_role {
      role_name = aws_iam_role.datadog_integration_role.name
    }
  }
}

resource "datadog_integration_aws_namespace_rules" "this" {
  account_id = var.aws_account_id

  namespace_rules = {
    ecs_fargate = true
  }
}

resource "aws_iam_role" "datadog_integration_role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::464622532012:root" # Datadog
      }
    }]
  })
}

resource "aws_iam_role_policy" "datadog_permissions" {
  name = "DatadogIntegrationPolicy"
  role = aws_iam_role.datadog_integration_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:DescribeAlarms",
          "ec2:DescribeInstances",
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
