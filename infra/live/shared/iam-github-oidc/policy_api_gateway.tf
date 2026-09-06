# CI role for the api-gateway component (live/api_gateway/dev).
# REST API, its WAF web ACL, and the VPC Link that reaches the NLB the api
# stack owns. API Gateway has no per-resource tagging model for authorization,
# so its statements are action-scoped rather than tag-conditioned.
#
# The stack also provisions its own observability plumbing: access log and WAF
# log groups, plus the role API Gateway assumes to write them.

resource "aws_iam_policy" "pipeline_api_gateway" {
  name        = "${var.project}-${var.environment}-pipeline-api-gateway-policy"
  description = "Pipeline policy for the api_gateway stack (API Gateway, WAF, VPC Link)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "APIGatewayRead"
        Effect = "Allow"
        Action = [
          "apigateway:GET",
          "elasticloadbalancing:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "APIGatewayWrite"
        Effect = "Allow"
        Action = [
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:PATCH",
          "apigateway:DELETE",
          "apigateway:TagResource",
          "apigateway:UntagResource",
          "apigateway:SetWebACL"
        ]
        Resource = "*"
      },
      {
        Sid    = "VPCLinkEndpointService"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpcEndpointServiceConfiguration",
          "ec2:DeleteVpcEndpointServiceConfigurations",
          "ec2:ModifyVpcEndpointServiceConfiguration",
          "ec2:ModifyVpcEndpointServicePermissions",
          "ec2:CreateTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:Describe*",
          "logs:Get*",
          "logs:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CreateTaggedLogGroups"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:TagLogGroup",
          "logs:TagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "ManageProjectLogGroups"
        Effect = "Allow"
        Action = [
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
          "logs:UntagLogGroup",
          "logs:UntagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
      # wafv2:PutLoggingConfiguration provisions a log delivery behind the
      # scenes and fails without these, even though the caller never names them.
      {
        Sid    = "WAFLogDelivery"
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
      },
      {
        Sid    = "CreateTaggedCloudWatchRole"
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
        Sid    = "ManageProjectCloudWatchRole"
        Effect = "Allow"
        Action = [
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:TagRole",
          "iam:UntagRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
      # Setting the account-level CloudWatch role hands it to API Gateway,
      # which is authorized separately from creating it.
      {
        Sid      = "PassCloudWatchRoleToApiGateway"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "*"
        Condition = {
          StringLike = {
            "iam:PassedToService" = "apigateway.amazonaws.com"
          }
        }
      },
      {
        Sid    = "WAFRead"
        Effect = "Allow"
        Action = [
          "wafv2:List*",
          "wafv2:Get*",
          "wafv2:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "WAFCreateTagged"
        Effect = "Allow"
        Action = [
          "wafv2:CreateWebACL",
          "wafv2:TagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "WAFManageProjectResources"
        Effect = "Allow"
        Action = [
          "wafv2:DeleteWebACL",
          "wafv2:UpdateWebACL",
          "wafv2:UntagResource",
          "wafv2:PutLoggingConfiguration",
          "wafv2:DeleteLoggingConfiguration"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
      # A web ACL that references AWS managed rule groups is authorized against
      # those rule groups as well as the ACL itself, and managed rule groups
      # carry no project tag, so they need an untagged grant scoped to their ARNs.
      {
        Sid    = "WAFManagedRuleGroups"
        Effect = "Allow"
        Action = [
          "wafv2:CreateWebACL",
          "wafv2:UpdateWebACL"
        ]
        Resource = ["arn:aws:wafv2:*:*:regional/managedruleset/*/*"]
      },
      {
        Sid    = "WAFAssociateWithGateway"
        Effect = "Allow"
        Action = [
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "wafv2:UpdateWebACL"
        ]
        Resource = [
          "arn:aws:wafv2:*:*:regional/webacl/*/*",
          "arn:aws:wafv2:*:*:regional/managedruleset/*/*",
          "arn:aws:apigateway:*::/restapis/*",
          "arn:aws:apigateway:*::/restapis/*/stages/*"
        ]
      }
    ]
  })

  tags = local.tags
}
