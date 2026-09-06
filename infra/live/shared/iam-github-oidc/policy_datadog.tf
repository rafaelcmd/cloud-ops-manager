# CI role for the datadog component (live/shared/datadog).
# Most of this stack talks to Datadog's API rather than AWS. Its AWS footprint
# is the integration role Datadog assumes to pull metrics, so the permissions
# are IAM role management plus attaching the AWS-managed SecurityAudit policy
# that role carries.

resource "aws_iam_policy" "pipeline_datadog" {
  name        = "${var.project}-${var.environment}-pipeline-datadog-policy"
  description = "Pipeline policy for the datadog stack (AWS integration role)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CreateTaggedIntegrationRole"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:TagRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "ManageProjectIntegrationRole"
        Effect = "Allow"
        Action = [
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:TagRole",
          "iam:UntagRole"
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
