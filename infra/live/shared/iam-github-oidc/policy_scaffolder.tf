# scaffolder component — infra/live/scaffolder/dev.
# The scaffolder's own state (one DynamoDB table), its Step Functions task queue
# and DLQ, and the IRSA role + policy its pod assumes. The kubernetes provider in
# that stack authenticates through eks:DescribeCluster, which is why the read
# statement includes it — the stack reads the cluster but never modifies it.
# The SSM parameters it publishes are covered by the common policy.
#
# It also creates the Secrets Manager secret that holds the GitHub App private
# key, and the KMS key encrypting it — but is explicitly denied the ability to
# read that secret's value. The pipeline's job is to create the container; the
# PEM is put in out of band by a human, so it never passes through a plan, a
# state file or a workflow log.

resource "aws_iam_policy" "pipeline_scaffolder" {
  name        = "${var.project}-${var.environment}-pipeline-scaffolder-policy"
  description = "Pipeline policy for the scaffolder stack (DynamoDB, SQS, IRSA)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadServicesInStack"
        Effect = "Allow"
        Action = [
          "dynamodb:List*",
          "dynamodb:Describe*",
          "sqs:List*",
          "sqs:Get*",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListTagsForResource",
          "eks:DescribeCluster",
          "states:List*",
          "states:Describe*",
          "secretsmanager:ListSecrets",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetResourcePolicy",
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus",
          "kms:ListAliases",
          "kms:ListResourceTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBCreateTagged"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:TagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "DynamoDBManageProjectTables"
        Effect = "Allow"
        Action = [
          "dynamodb:DeleteTable",
          "dynamodb:UpdateTable",
          "dynamodb:UpdateTimeToLive",
          "dynamodb:UpdateContinuousBackups",
          "dynamodb:CreateTableReplica",
          "dynamodb:DeleteTableReplica",
          "dynamodb:UntagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "SQSCreateTagged"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:TagQueue"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        # SQS has no resource-tag condition key for these actions, so they are
        # scoped by queue name instead — the same prefix every resource in this
        # stack is named with.
        Sid    = "SQSManageScaffolderQueues"
        Effect = "Allow"
        Action = [
          "sqs:DeleteQueue",
          "sqs:SetQueueAttributes",
          "sqs:UntagQueue",
          "sqs:AddPermission",
          "sqs:RemovePermission"
        ]
        Resource = "arn:aws:sqs:*:*:${var.project}-scaffolder-*"
      },
      {
        # The dead-letter queue alarms modules/aws/sqs creates. Nothing watched
        # those queues before, so a scaffold task that exhausted its retries
        # stayed unread until retention expired.
        Sid    = "CloudWatchCreateTaggedAlarms"
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
        # PutMetricAlarm appears here as well as above: updating an existing
        # alarm is the same call, and a request that does not resend the tags
        # is authorized against the alarm's tags rather than the request's.
        Sid    = "CloudWatchManageProjectAlarms"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
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
        Sid    = "SecretsManagerCreateTagged"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:TagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "SecretsManagerManageProjectSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:DeleteSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:RestoreSecret",
          "secretsmanager:UntagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
      {
        # The control that makes the two-role split in the scaffolder stack
        # meaningful. Terraform must be able to create the secret and never to
        # read it; an explicit Deny survives someone later widening an Allow
        # somewhere else in this role.
        Sid    = "NeverReadSecretValues"
        Effect = "Deny"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSCreateTagged"
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:TagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        # Aliases carry no tags of their own, so they are scoped by name — the
        # same prefix every resource in this stack is named with.
        Sid    = "KMSManageScaffolderAliases"
        Effect = "Allow"
        Action = [
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:UpdateAlias"
        ]
        Resource = [
          "arn:aws:kms:*:*:alias/${var.project}-scaffolder-*",
          "arn:aws:kms:*:*:key/*"
        ]
      },
      {
        # Creating a secret encrypted with a customer-managed key is not purely
        # administrative: Secrets Manager encrypts through a grant it asks the
        # caller to create on the key. Without these, CreateSecret fails with
        # "Access to KMS is not allowed" even though the key was created
        # successfully by the statements above.
        #
        # CreateGrant is limited to grants made on behalf of an AWS service, so
        # it cannot hand this key to an arbitrary principal, and the data-key
        # operations only work when Secrets Manager is the caller.
        Sid    = "KMSUseKeyThroughSecretsManager"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant",
          "kms:RetireGrant"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "KMSEncryptThroughSecretsManager"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
            "kms:ViaService"          = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "KMSManageProjectKeys"
        Effect = "Allow"
        Action = [
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:EnableKeyRotation",
          "kms:DisableKeyRotation",
          "kms:PutKeyPolicy",
          "kms:UntagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
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
