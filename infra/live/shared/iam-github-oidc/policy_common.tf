# Baseline attached to every per-component pipeline role.
#
# Two things every stack needs regardless of what it provisions: read access
# for Terraform's state refresh and data sources, and SSM parameter access.
# Stacks are decoupled through SSM rather than remote state, so each one reads
# the parameters its producers published and writes its own.

resource "aws_iam_policy" "pipeline_common" {
  name        = "${var.project}-${var.environment}-pipeline-common-policy"
  description = "Read-only describes plus SSM parameter access shared by every pipeline role"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DescribeForRefreshAndDataSources"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "iam:Get*",
          "iam:List*",
          "kms:Describe*",
          "kms:List*",
          "tag:GetResources"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMRead"
        Effect = "Allow"
        Action = [
          "ssm:DescribeParameters",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory",
          "ssm:GetParametersByPath",
          "ssm:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMCreateTagged"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:AddTagsToResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "SSMManageProjectParameters"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:DeleteParameters",
          "ssm:AddTagsToResource",
          "ssm:RemoveTagsFromResource"
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

  tags = local.tags
}
