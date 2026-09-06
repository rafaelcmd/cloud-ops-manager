# One IAM role and one ServiceAccount per worker (see local.workers in
# locals.tf), assumed through the cluster's OIDC provider. The role, its trust
# relationship and the annotated ServiceAccount come from modules/aws/irsa; the
# cluster's OIDC coordinates come from SSM because the cluster belongs to
# another workspace.
#
# The two roles are deliberately not identical. Both need the table and their
# own queue; only the github worker's may read the GitHub App private key. The
# policy documents stay in this file rather than moving into the module so that
# the difference between the workers is visible in one place. See
# docs/adr/0004-scaffolder-runs-as-a-container-on-eks.md.

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

  # The service's own table, and no other. Both workers write to it: the github
  # worker owns the repository inventory and the state worker owns name
  # reservations, so table access is not what the split separates.
  statement {
    sid = "ScaffolderTable"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
    ]
    resources = [
      module.table.table_arn,
      "${module.table.table_arn}/index/*",
    ]
  }

  # The consume side of this worker's own queue, and no other. GetQueueUrl is
  # what lets the pod be configured with a queue name rather than an
  # account-qualified URL.
  statement {
    sid = "ScaffolderTaskQueue"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [module.task_queue[each.key].queue_arn]
  }

  # Step Functions callbacks. These three actions take a task token rather than
  # a resource ARN and the API supports no resource-level permissions for them,
  # so the wildcard is unavoidable. The grant is inert without a valid token.
  statement {
    sid = "ScaffolderTaskCallbacks"
    actions = [
      "states:SendTaskSuccess",
      "states:SendTaskFailure",
      "states:SendTaskHeartbeat",
    ]
    resources = ["*"]
  }

  # The reason there are two roles at all. Granted to exactly one worker, with
  # the KMS grant scoped by ViaService so the key cannot decrypt anything other
  # than this secret.
  dynamic "statement" {
    for_each = each.value.reads_github_app_key ? [1] : []

    content {
      sid       = "GitHubAppPrivateKey"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [module.github_app_key.secret_arn]
    }
  }

  dynamic "statement" {
    for_each = each.value.reads_github_app_key ? [1] : []

    content {
      sid       = "GitHubAppPrivateKeyDecrypt"
      actions   = ["kms:Decrypt"]
      resources = [module.github_app_key.kms_key_arn]

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
