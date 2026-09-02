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

module "table" {
  source = "../../../modules/aws/dynamodb"

  name      = "${local.name_prefix}-${var.environment}"
  hash_key  = "PK"
  range_key = "SK"

  # Only the key attributes are declared: DynamoDB rejects a table that declares
  # an attribute nothing keys on, so the item bodies above do not appear here.
  attributes = [
    { name = "PK", type = "S" },
    { name = "SK", type = "S" },
  ]

  # Abandoned scaffolds release their name automatically. The adapter writes
  # ExpiresAt as epoch seconds, which is the only shape DynamoDB TTL reads.
  ttl_attribute_name = "ExpiresAt"

  point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
  deletion_protection_enabled    = var.deletion_protection_enabled

  tags = local.tags
}

# =============================================================================
# TASK QUEUES
#
# One queue and one dead-letter queue per worker in local.workers. The per-queue
# split is what makes the IAM split in irsa.tf effective: two Deployments
# polling a shared queue would each receive the other's tasks.
#
# Step Functions is the only sender; the consume side is each worker's IRSA
# role, granted in irsa.tf against the queue it owns. The module's
# aws:SourceAccount condition on the service principal is what stops another
# account's state machine from sending here.
# =============================================================================

module "task_queue" {
  source   = "../../../modules/aws/sqs"
  for_each = local.workers

  queue_name = "${local.name_prefix}-${each.key}-tasks-${var.environment}"

  # Must exceed the slowest task, or SQS hands the same message to a second
  # consumer while the first is still working. Raise it before adding a task
  # that takes longer than a template render and a push.
  visibility_timeout_seconds = var.task_visibility_timeout_seconds
  message_retention_seconds  = var.task_message_retention_seconds

  # The worker deliberately leaves a message on the queue when it cannot report
  # an outcome to Step Functions, so redrive is the backstop for a payload no
  # build of the worker can handle.
  max_receive_count             = var.task_max_receive_count
  dlq_message_retention_seconds = var.dlq_message_retention_seconds

  producer_service_principals = ["states.amazonaws.com"]

  tags = local.tags
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

module "github_app_key" {
  source = "../../../modules/aws/secrets_manager"

  name        = "${local.name_prefix}-github-app-key-${var.environment}"
  description = "PEM private key for the GitHub App the scaffolder authenticates as"
  alias_name  = "alias/${local.name_prefix}-github-app-${var.environment}"

  kms_deletion_window_in_days = var.kms_deletion_window_in_days

  # Zero in dev so that ops-platform-down followed by ops-platform-up can reuse
  # the name. With a recovery window the name stays reserved after a destroy and
  # the next apply fails with "already scheduled for deletion". Set to 7 or more
  # in any environment that is not rebuilt from scratch.
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
  value = module.table.table_name
  tags  = local.tags
}

resource "aws_ssm_parameter" "task_queue_arn" {
  for_each = local.workers

  name  = "/idp/${var.service_name}/${var.environment}/${each.key}_task_queue_arn"
  type  = "String"
  value = module.task_queue[each.key].queue_arn
  tags  = local.tags
}

resource "aws_ssm_parameter" "task_queue_name" {
  for_each = local.workers

  name  = "/idp/${var.service_name}/${var.environment}/${each.key}_task_queue_name"
  type  = "String"
  value = module.task_queue[each.key].queue_name
  tags  = local.tags
}

resource "aws_ssm_parameter" "github_app_key_secret_arn" {
  name  = "/idp/${var.service_name}/${var.environment}/github_app_key_secret_arn"
  type  = "String"
  value = module.github_app_key.secret_arn
  tags  = local.tags
}
