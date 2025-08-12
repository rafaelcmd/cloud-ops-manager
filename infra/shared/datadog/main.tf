resource "datadog_integration_aws_account" "this" {
  aws_account_id = var.aws_account_id
  aws_partition  = var.aws_partition
  account_tags   = ["env:prod"]

  aws_regions {
    include_all = true
  }

  auth_config {
    aws_auth_config_role {
      role_name = aws_iam_role.datadog_integration_role.name
    }
  }

  logs_config {
    lambda_forwarder {}
  }

  metrics_config {
    namespace_filters {
      # Include ECS metrics for cluster monitoring
      include_only = [
        "AWS/ECS",
        "AWS/ApplicationELB",
        "AWS/Logs"
      ]
    }
  }

  resources_config {
    # Enable resource collection for ECS clusters
    cloud_security_posture_management_collection = false
    extended_collection                          = true
  }

  traces_config {
    xray_services {}
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
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTaskSets",
          "ecs:DescribeContainerInstances",
          "ecs:ListClusters",
          "ecs:ListServices",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:ListContainerInstances",
          "ecs:ListTaskDefinitions",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "tag:GetResources"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
