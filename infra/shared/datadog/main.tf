# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get current AWS partition
data "aws_partition" "current" {}

# IAM Role for Datadog AWS Integration
resource "aws_iam_role" "datadog_integration_role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::464622532012:root"
      }
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.external_id
        }
      }
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# IAM Policy for Datadog Integration
resource "aws_iam_role_policy" "datadog_integration_policy" {
  name = "DatadogIntegrationPolicy"
  role = aws_iam_role.datadog_integration_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:Describe*",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "ec2:Describe*",
          "ecs:Describe*",
          "ecs:List*",
          "elasticloadbalancing:Describe*",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:FilterLogEvents",
          "rds:Describe*",
          "rds:List*",
          "s3:GetBucketLocation",
          "s3:GetBucketTagging",
          "s3:ListAllMyBuckets",
          "tag:GetResources",
          "tag:GetTagKeys",
          "tag:GetTagValues"
        ]
        Resource = "*"
      }
    ]
  })
}

# Datadog AWS Integration
resource "datadog_integration_aws_account" "this" {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_partition  = data.aws_partition.current.partition

  aws_regions {

  }

  auth_config {
    aws_auth_config_role {
      role_name   = aws_iam_role.datadog_integration_role.name
      external_id = var.external_id
    }
  }

  logs_config {
    lambda_forwarder {
      lambdas = [var.forwarder_name]
    }
  }

  metrics_config {
    namespace_filters {

    }
  }

  traces_config {
    xray_services {

    }
  }

  resources_config {

  }

  depends_on = [aws_iam_role_policy.datadog_integration_policy]
}
