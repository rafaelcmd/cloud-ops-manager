# CI role for the provisioner component (live/provisioner/dev).
# The consumer's IRSA role and policy, and the ServiceAccount it annotates. That
# is the whole of the stack, so this is the smallest of the component policies:
# no service to create, only an identity.
#
# The queue and the cluster belong to the api component; this pipeline reads
# both (eks:DescribeCluster for the kubernetes provider's exec auth, sqs:Get* to
# resolve the queue it writes into the policy) and modifies neither. The SSM
# parameters it reads are covered by the common policy.

resource "aws_iam_policy" "pipeline_provisioner" {
  name        = "${var.project}-${var.environment}-pipeline-provisioner-policy"
  description = "Pipeline policy for the provisioner stack (IRSA only)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadServicesInStack"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "sqs:List*",
          "sqs:Get*"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMCreateTaggedRolesAndPolicies"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:CreatePolicy",
          "iam:TagRole",
          "iam:TagPolicy"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "IAMManageProjectRolesAndPolicies"
        Effect = "Allow"
        Action = [
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:TagPolicy",
          "iam:UntagPolicy"
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
