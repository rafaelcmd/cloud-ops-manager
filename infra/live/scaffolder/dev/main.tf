# =============================================================================
# SCAFFOLDER STATE
# One DynamoDB table for the whole service. On-demand billing because scaffold
# traffic is bursty and rare — provisioned capacity would be sized for a peak
# that happens a few times a day.
#
# | Item              | PK                    | SK                |
# |-------------------|-----------------------|-------------------|
# | Template version  | TEMPLATE#<name>       | VERSION#<semver>  |
# | Name reservation  | NAME#<app-name>       | RESERVATION       |
# | Repository record | REPO#<owner>/<name>   | META              |
# =============================================================================

resource "aws_dynamodb_table" "scaffolder" {
  name         = "${local.name_prefix}-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # Abandoned scaffolds release their name automatically. The adapter writes
  # ExpiresAt as epoch seconds, which is the only shape DynamoDB TTL reads.
  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  deletion_protection_enabled = var.deletion_protection_enabled

  tags = local.tags
}

# =============================================================================
# TASK QUEUES
# One per worker (see local.workers): the IAM split is only real if the routing
# matches it. Written as plain resources rather than through modules/aws/sqs —
# that module is shaped for the provisioner's queue and exposes neither a
# visibility timeout nor a redrive policy, both of which these queues need.
# =============================================================================

resource "aws_sqs_queue" "tasks_dlq" {
  for_each = local.workers

  name                      = "${local.name_prefix}-${each.key}-tasks-dlq-${var.environment}"
  message_retention_seconds = var.dlq_message_retention_seconds

  tags = local.tags
}

resource "aws_sqs_queue" "tasks" {
  for_each = local.workers

  name = "${local.name_prefix}-${each.key}-tasks-${var.environment}"

  # Long enough for the slowest task to finish before SQS hands the same message
  # to a second consumer. Raise this before adding a task that takes longer than
  # a template render and a push.
  visibility_timeout_seconds = var.task_visibility_timeout_seconds
  message_retention_seconds  = var.task_message_retention_seconds

  # The worker deliberately leaves a message on the queue when it cannot report
  # an outcome to Step Functions, so this redrive is the backstop for a payload
  # no build of the worker can handle.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.tasks_dlq[each.key].arn
    maxReceiveCount     = var.task_max_receive_count
  })

  tags = local.tags
}

# Only Step Functions puts messages here. The consume side is the pod's IRSA
# role; nothing else in the account has a reason to send.
data "aws_iam_policy_document" "tasks_queue" {
  for_each = local.workers

  statement {
    sid       = "AllowStatesToSendTasks"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.tasks[each.key].arn]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sqs_queue_policy" "tasks" {
  for_each = local.workers

  queue_url = aws_sqs_queue.tasks[each.key].id
  policy    = data.aws_iam_policy_document.tasks_queue[each.key].json
}

# =============================================================================
# GITHUB APP CREDENTIAL
# The App's PEM private key. Terraform creates the secret and its key; it does
# NOT create a version — the PEM is put in out of band, so the credential never
# passes through a plan, a state file or a CI log.
#
#   aws secretsmanager put-secret-value \
#     --secret-id internal-developer-platform-scaffolder-github-app-key-dev \
#     --secret-string file://idp-scaffolder.private-key.pem
#
# Only the github worker's role can read it. That restriction is the entire
# point of the two-Deployment split above.
# =============================================================================

resource "aws_kms_key" "github_app" {
  description             = "Encrypts the scaffolder's GitHub App private key"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  tags = local.tags
}

resource "aws_kms_alias" "github_app" {
  name          = "alias/${local.name_prefix}-github-app-${var.environment}"
  target_key_id = aws_kms_key.github_app.key_id
}

resource "aws_secretsmanager_secret" "github_app_key" {
  name        = "${local.name_prefix}-github-app-key-${var.environment}"
  description = "PEM private key for the GitHub App the scaffolder authenticates as"
  kms_key_id  = aws_kms_key.github_app.arn

  # Dev is torn down and rebuilt by ops-platform-down / ops-platform-up. With a
  # recovery window the name stays reserved after a destroy and the next apply
  # fails with "already scheduled for deletion", which is a confusing way to
  # learn that. A longer-lived environment must set this back to 7+.
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = local.tags
}

# =============================================================================
# PUBLISHED VALUES
# The pods resolve the table and their own queue by name from their environment,
# so these exist for other stacks — the scaffold state machine, when it is built,
# needs the queue ARNs to target.
# =============================================================================

resource "aws_ssm_parameter" "table_name" {
  name  = "/idp/${var.service_name}/${var.environment}/table_name"
  type  = "String"
  value = aws_dynamodb_table.scaffolder.name
  tags  = local.tags
}

resource "aws_ssm_parameter" "task_queue_arn" {
  for_each = local.workers

  name  = "/idp/${var.service_name}/${var.environment}/${each.key}_task_queue_arn"
  type  = "String"
  value = aws_sqs_queue.tasks[each.key].arn
  tags  = local.tags
}

resource "aws_ssm_parameter" "task_queue_name" {
  for_each = local.workers

  name  = "/idp/${var.service_name}/${var.environment}/${each.key}_task_queue_name"
  type  = "String"
  value = aws_sqs_queue.tasks[each.key].name
  tags  = local.tags
}

resource "aws_ssm_parameter" "github_app_key_secret_arn" {
  name  = "/idp/${var.service_name}/${var.environment}/github_app_key_secret_arn"
  type  = "String"
  value = aws_secretsmanager_secret.github_app_key.arn
  tags  = local.tags
}
