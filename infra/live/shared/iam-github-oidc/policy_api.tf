# CI role for the api component (live/api/dev).
# The largest surface: EKS (cluster, Fargate profiles, addons, access entries),
# the IRSA plumbing that needs IAM role and OIDC provider management, SQS, the
# Terraform-managed NLB, cluster log groups, and the SNS/CloudWatch alerting
# this stack owns. The kubernetes provider authenticates through
# eks:DescribeCluster, covered by the read statement.

resource "aws_iam_policy" "pipeline_api" {
  name        = "${var.project}-${var.environment}-pipeline-api-policy"
  description = "Pipeline policy for the api stack (EKS, SQS, NLB, IRSA, alerting)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadServicesInStack"
        Effect = "Allow"
        Action = [
          "eks:List*",
          "eks:Describe*",
          "sqs:List*",
          "sqs:Get*",
          "elasticloadbalancing:Describe*",
          "logs:Describe*",
          "logs:Get*",
          "logs:List*",
          "sns:List*",
          "sns:Get*",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSCreateTagged"
        Effect = "Allow"
        Action = [
          "eks:CreateCluster",
          "eks:CreateFargateProfile",
          "eks:CreateNodegroup",
          "eks:CreateAddon",
          "eks:CreateAccessEntry",
          "eks:TagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "EKSManageProjectResources"
        Effect = "Allow"
        Action = [
          "eks:DeleteCluster",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:DeleteFargateProfile",
          "eks:DeleteNodegroup",
          "eks:UpdateNodegroupConfig",
          "eks:DeleteAddon",
          "eks:UpdateAddon",
          "eks:DeleteAccessEntry",
          "eks:UpdateAccessEntry",
          "eks:AssociateAccessPolicy",
          "eks:DisassociateAccessPolicy",
          "eks:AssociateIdentityProviderConfig",
          "eks:DisassociateIdentityProviderConfig",
          "eks:UntagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
      # Same parent-resource rule as security groups: EKS authorizes profile,
      # addon and access-entry creation against the cluster that contains them.
      # The cluster is pre-existing in those calls, so request tags never apply.
      {
        Sid    = "EKSSubresourcesOnProjectCluster"
        Effect = "Allow"
        Action = [
          "eks:CreateFargateProfile",
          "eks:CreateAddon",
          "eks:CreateAccessEntry",
          "eks:AssociateAccessPolicy",
          "eks:AssociateIdentityProviderConfig",
          "eks:TagResource"
        ]
        Resource = "arn:aws:eks:*:*:cluster/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "IAMOpenIDConnectProviderForIRSA"
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:AddClientIDToOpenIDConnectProvider",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagOpenIDConnectProvider"
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
      },
      {
        Sid      = "IAMServiceLinkedRole"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "arn:aws:iam::*:role/aws-service-role/*"
      },
      {
        Sid      = "IAMPassRoleToClusterServices"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "*"
        Condition = {
          StringLike = {
            "iam:PassedToService" = [
              "eks.amazonaws.com",
              "eks-fargate-pods.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "EKSManagedSecurityGroups"
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      # ec2:CreateSecurityGroup is authorized against two resources: the group
      # being created and the VPC it goes into. The statement above covers the
      # first through its request tags; the VPC already exists and carries no
      # request tag, so it needs its own grant keyed on the tag it does have.
      {
        Sid    = "CreateSecurityGroupInProjectVpc"
        Effect = "Allow"
        Action = ["ec2:CreateSecurityGroup"]
        Resource = [
          "arn:aws:ec2:*:*:vpc/*",
          "arn:aws:ec2:*:*:security-group/*"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "EKSManageProjectSecurityGroups"
        Effect = "Allow"
        Action = [
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "CreateTaggedStackResources"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:TagQueue",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:AddTags",
          "logs:CreateLogGroup",
          "logs:TagLogGroup",
          "sns:CreateTopic",
          "sns:TagResource",
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
        Sid    = "ManageProjectStackResources"
        Effect = "Allow"
        Action = [
          "sqs:DeleteQueue",
          "sqs:SetQueueAttributes",
          "sqs:UntagQueue",
          "sqs:AddPermission",
          "sqs:RemovePermission",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:RemoveTags",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:UntagLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "sns:DeleteTopic",
          "sns:SetTopicAttributes",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:UntagResource",
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
      },
      {
        Sid    = "CloudWatchLogsDelivery"
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}
