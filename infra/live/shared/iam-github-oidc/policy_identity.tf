# CI role for the identity component (live/shared/identity).
# Cognito user pools, clients, groups and domains. The client id it publishes
# to SSM is covered by the common policy.

resource "aws_iam_policy" "pipeline_identity" {
  name        = "${var.project}-${var.environment}-pipeline-identity-policy"
  description = "Pipeline policy for the identity stack (Cognito)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CognitoRead"
        Effect = "Allow"
        Action = [
          "cognito-idp:List*",
          "cognito-idp:Describe*",
          "cognito-idp:Get*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CognitoCreateTagged"
        Effect = "Allow"
        Action = [
          "cognito-idp:CreateUserPool",
          "cognito-idp:TagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "CognitoManageProjectResources"
        Effect = "Allow"
        Action = [
          "cognito-idp:DeleteUserPool",
          "cognito-idp:UpdateUserPool",
          "cognito-idp:CreateUserPoolClient",
          "cognito-idp:DeleteUserPoolClient",
          "cognito-idp:UpdateUserPoolClient",
          "cognito-idp:CreateGroup",
          "cognito-idp:DeleteGroup",
          "cognito-idp:UpdateGroup",
          "cognito-idp:AdminCreateUser",
          "cognito-idp:AdminDeleteUser",
          "cognito-idp:CreateUserPoolDomain",
          "cognito-idp:DeleteUserPoolDomain",
          "cognito-idp:UntagResource"
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
