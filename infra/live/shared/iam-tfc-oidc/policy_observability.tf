# Alerting permissions for the Terraform Cloud role: the SNS topic alarms
# publish to, and the CloudWatch alarms themselves.

resource "aws_iam_policy" "provisioner_api_observability_policy" {
  name        = "${var.project}-${var.environment}-provisioner-api-observability-policy"
  description = "Least privilege policy for the observability stack (SNS alert topic + CloudWatch metric alarms)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # The alert topic alarms publish to, and its subscriptions.
      {
        Sid    = "SNSRead"
        Effect = "Allow"
        Action = [
          "sns:List*",
          "sns:Get*"
        ]
        Resource = "*"
      },
      {
        Sid    = "SNSCreateTagged"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:TagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "SNSManageProjectResources"
        Effect = "Allow"
        Action = [
          "sns:DeleteTopic",
          "sns:SetTopicAttributes",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:UntagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
      # The alarms themselves.
      {
        Sid    = "CloudWatchAlarmsRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchAlarmsCreateTagged"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:TagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "CloudWatchAlarmsManageProjectResources"
        Effect = "Allow"
        Action = [
          "cloudwatch:DeleteAlarms",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:UntagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      }
    ]
  })
}
