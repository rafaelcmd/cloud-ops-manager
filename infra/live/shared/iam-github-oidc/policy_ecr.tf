# CI role for the ecr component (live/shared/ecr).
# Repository lifecycle plus the image push the apply performs afterwards: the
# workflow mirrors the Datadog agent from public ECR into the private registry,
# which needs both registries' auth tokens and the layer upload actions.

resource "aws_iam_policy" "pipeline_ecr" {
  name        = "${var.project}-${var.environment}-pipeline-ecr-policy"
  description = "Pipeline policy for the ecr stack (repository lifecycle + agent image mirror)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRRead"
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories",
          "ecr:ListTagsForResource",
          "ecr:GetLifecyclePolicy",
          "ecr:GetRepositoryPolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      {
        Sid    = "CreateTaggedRepository"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:TagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "ManageProjectRepository"
        Effect = "Allow"
        Action = [
          "ecr:DeleteRepository",
          "ecr:PutLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:StartLifecyclePolicyPreview",
          "ecr:SetRepositoryPolicy",
          "ecr:DeleteRepositoryPolicy",
          "ecr:PutImageScanningConfiguration",
          "ecr:UntagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "ECRPushDatadogAgentMirror"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr-public:GetAuthorizationToken",
          "sts:GetServiceBearerToken"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}
