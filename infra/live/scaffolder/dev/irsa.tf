# =============================================================================
# SCAFFOLDER IRSA
# One role and one ServiceAccount per worker (see local.workers), assumed
# through the cluster OIDC provider. The role, its trust relationship and the
# annotated ServiceAccount come from modules/aws/irsa; the cluster's OIDC
# coordinates come from SSM rather than a module reference because the cluster
# lives in a different workspace.
#
# The roles are deliberately not identical. Both need the table and their own
# queue; only the github worker's may read the App private key. That is the
# per-function isolation ADR-0004 gave up when this service left Lambda, put
# back in the form a container platform can express — which is why the policy
# documents stay here, where the difference between the two workers is visible,
# rather than inside the module.
# =============================================================================

locals {
  service_account_namespace = "default"

  service_account_names = {
    for worker in keys(local.workers) :
    worker => "${local.name_prefix}-${worker}"
  }

  eks_oidc_provider_url = data.aws_ssm_parameter.eks_oidc_provider_url.value
}

data "aws_iam_policy_document" "worker" {
  for_each = local.workers

  # DynamoDB: the service's own table only. Both workers write to it — the
  # github worker owns the repository inventory, the state worker owns name
  # reservations — so this is not what the split separates.
  statement {
    sid = "ScaffolderTable"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
    ]
    resources = [
      aws_dynamodb_table.scaffolder.arn,
      "${aws_dynamodb_table.scaffolder.arn}/index/*",
    ]
  }

  # SQS: consume side of this worker's own queue, and no other. GetQueueUrl is
  # what lets the pod be configured with a queue name instead of an
  # account-qualified URL.
  statement {
    sid = "ScaffolderTaskQueue"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [aws_sqs_queue.tasks[each.key].arn]
  }

  # Step Functions callbacks. These three take a task token, not a resource
  # ARN, and the API does not support resource-level permissions for them —
  # hence the wildcard. Holding them is meaningless without a valid token.
  statement {
    sid = "ScaffolderTaskCallbacks"
    actions = [
      "states:SendTaskSuccess",
      "states:SendTaskFailure",
      "states:SendTaskHeartbeat",
    ]
    resources = ["*"]
  }

  # The whole reason there are two roles. Granted to exactly one worker, and the
  # KMS grant is scoped by ViaService so this key cannot be used to decrypt
  # anything that is not this secret.
  dynamic "statement" {
    for_each = each.value.reads_github_app_key ? [1] : []

    content {
      sid       = "GitHubAppPrivateKey"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [aws_secretsmanager_secret.github_app_key.arn]
    }
  }

  dynamic "statement" {
    for_each = each.value.reads_github_app_key ? [1] : []

    content {
      sid       = "GitHubAppPrivateKeyDecrypt"
      actions   = ["kms:Decrypt"]
      resources = [aws_kms_key.github_app.arn]

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
      }
    }
  }
}

module "worker_irsa" {
  source   = "../../../modules/aws/irsa"
  for_each = local.workers

  role_name          = "${local.name_prefix}-${each.key}-${var.environment}"
  role_description   = "Scaffolder ${each.key} worker: ${each.value.description}"
  policy_description = "Permissions for the scaffolder ${each.key} worker pod"
  policy_json        = data.aws_iam_policy_document.worker[each.key].json

  oidc_provider_arn = data.aws_ssm_parameter.eks_oidc_provider_arn.value
  oidc_provider_url = local.eks_oidc_provider_url

  namespace            = local.service_account_namespace
  service_account_name = local.service_account_names[each.key]

  service_account_labels = {
    "app.kubernetes.io/component" = each.key
  }

  tags = local.tags
}
