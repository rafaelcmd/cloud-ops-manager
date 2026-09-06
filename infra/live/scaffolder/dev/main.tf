# The scaffolder owns the repository half of a provision request: it creates
# GitHub repositories from golden-path templates and wires their CI/CD. This
# stack provisions its state store, its task queues, the credential it
# authenticates to GitHub with, and one IAM identity per worker.
#
# A single table holds every kind of item, keyed as follows. On-demand billing
# because scaffold traffic is bursty and rare, and provisioned capacity would be
# sized for a peak that occurs a few times a day.
#
# | Item              | PK                    | SK                |
# |-------------------|-----------------------|-------------------|
# | Template version  | TEMPLATE#<name>       | VERSION#<semver>  |
# | Name reservation  | NAME#<app-name>       | RESERVATION       |
# | Repository record | REPO#<owner>/<name>   | META              |

module "table" {
  source = "../../../modules/aws/dynamodb"

  name      = "${local.name_prefix}-${var.environment}"
  hash_key  = "PK"
  range_key = "SK"

  # Only key attributes are declared. DynamoDB rejects a table that declares an
  # attribute nothing keys on, so the item bodies above do not appear here.
  attributes = [
    { name = "PK", type = "S" },
    { name = "SK", type = "S" },
  ]

  # Abandoned scaffolds release their reserved name automatically. The adapter
  # writes ExpiresAt as epoch seconds, the only shape DynamoDB TTL evaluates.
  ttl_attribute_name = "ExpiresAt"

  point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
  deletion_protection_enabled    = var.deletion_protection_enabled

  tags = local.tags
}

# One queue and one dead-letter queue per worker in local.workers. The per-queue
# split is what makes the IAM split in irsa.tf effective: two Deployments
# polling a shared queue would each receive the other's tasks.
#
# Step Functions is the only sender. The consume side is each worker's IRSA
# role, granted in irsa.tf against the queue it owns.
module "task_queue" {
  source   = "../../../modules/aws/sqs"
  for_each = local.workers

  queue_name = "${local.name_prefix}-${each.key}-tasks-${var.environment}"

  # Must exceed the slowest task, or SQS delivers the same message to a second
  # consumer while the first is still working. Raise it before adding a task
  # that takes longer than a template render and a push.
  visibility_timeout_seconds = var.task_visibility_timeout_seconds
  message_retention_seconds  = var.task_message_retention_seconds

  # The worker leaves a message on the queue when it cannot report an outcome to
  # Step Functions, so redrive is the backstop for a payload no build of the
  # worker can handle.
  max_receive_count             = var.task_max_receive_count
  dlq_message_retention_seconds = var.dlq_message_retention_seconds

  producer_service_principals = ["states.amazonaws.com"]

  # A task reaching the dead-letter queue is a scaffold stopped halfway: the
  # name is reserved, the repository may or may not exist, and the state machine
  # is waiting for a token that will never arrive.
  alarm_actions = [data.aws_ssm_parameter.observability_alerts_topic_arn.value]

  tags = local.tags
}

# The GitHub App's PEM private key, which is what the scaffolder authenticates
# to GitHub with. Terraform creates the secret and its KMS key but no secret
# version: the PEM is written out of band, so the credential never passes
# through a plan, a state file or a CI log.
#
#   aws secretsmanager put-secret-value \
#     --secret-id internal-developer-platform-scaffolder-github-app-key-dev \
#     --secret-string file://idp-scaffolder.private-key.pem
#
# Only the github worker's role may read it, which is the point of the
# two-Deployment split in locals.tf.

module "github_app_key" {
  source = "../../../modules/aws/secrets_manager"

  name        = "${local.name_prefix}-github-app-key-${var.environment}"
  description = "PEM private key for the GitHub App the scaffolder authenticates as"
  alias_name  = "alias/${local.name_prefix}-github-app-${var.environment}"

  kms_deletion_window_in_days = var.kms_deletion_window_in_days

  # Zero in dev so ops-platform-down followed by ops-platform-up can reuse the
  # name. With a recovery window the name stays reserved after a destroy and the
  # next apply fails with "already scheduled for deletion". Set 7 or more in any
  # environment that is not routinely rebuilt from scratch.
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = local.tags
}

# Published for other stacks. The pods themselves resolve the table and their
# own queue by name from their environment; these exist for the scaffold state
# machine, which will need the queue ARNs to target once it is built.

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
