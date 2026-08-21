# =============================================================================
# SCAFFOLDER IRSA
# One role and one ServiceAccount per worker (see local.workers), assumed
# through the cluster OIDC provider. Mirrors provisioner_irsa.tf in the api
# component; the cluster's OIDC coordinates come from SSM rather than a module
# reference because the cluster lives in a different workspace.
#
# The roles are deliberately not identical. Both need the table and their own
# queue; only the github worker's may read the App private key. That is the
# per-function isolation ADR-0004 gave up when this service left Lambda, put
# back in the form a container platform can express.
# =============================================================================

locals {
  service_account_namespace = "default"

  service_account_names = {
    for worker in keys(local.workers) :
    worker => "${local.name_prefix}-${worker}"
  }

  eks_oidc_provider_url = data.aws_ssm_parameter.eks_oidc_provider_url.value
}

data "aws_iam_policy_document" "assume_role" {
  for_each = local.workers

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_ssm_parameter.eks_oidc_provider_arn.value]
    }

    # Scoped to one ServiceAccount, not to the namespace: without this a pod in
    # `default` running any other ServiceAccount could assume the role.
    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${local.service_account_namespace}:${local.service_account_names[each.key]}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "worker" {
  for_each = local.workers

  name               = "${local.name_prefix}-${each.key}-${var.environment}"
  description        = "Scaffolder ${each.key} worker: ${each.value.description}"
  assume_role_policy = data.aws_iam_policy_document.assume_role[each.key].json
  tags               = local.tags
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

resource "aws_iam_policy" "worker" {
  for_each = local.workers

  name        = "${local.name_prefix}-${each.key}-${var.environment}-policy"
  description = "Permissions for the scaffolder ${each.key} worker pod"
  policy      = data.aws_iam_policy_document.worker[each.key].json
  tags        = local.tags
}

resource "aws_iam_role_policy_attachment" "worker" {
  for_each = local.workers

  role       = aws_iam_role.worker[each.key].name
  policy_arn = aws_iam_policy.worker[each.key].arn
}

resource "kubernetes_service_account" "worker" {
  for_each = local.workers

  metadata {
    name      = local.service_account_names[each.key]
    namespace = local.service_account_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.worker[each.key].arn
    }
    labels = {
      "app.kubernetes.io/name"       = local.service_account_names[each.key]
      "app.kubernetes.io/component"  = each.key
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}
