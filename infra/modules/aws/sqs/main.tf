# SQS work queue with an optional dead-letter queue, resource policy and
# not-empty alarm. Used for every asynchronous hop in the platform: the API to
# the provisioner, and the provisioner's state machine to each task worker.
#
# Consumers resolve queues by name, so the caller owns the name. Every other
# setting defaults to a value that is safe for a work queue.

data "aws_caller_identity" "current" {}

# Retained longer than the main queue because it is read during investigation,
# often days after the failure.
resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0

  name                      = "${var.queue_name}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds

  sqs_managed_sse_enabled = var.sqs_managed_sse_enabled

  tags = var.tags
}

resource "aws_sqs_queue" "this" {
  name                       = var.queue_name
  delay_seconds              = var.delay_seconds
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds

  # Queues created through the API are unencrypted by default; only queues
  # created in the console are encrypted. Platform messages carry application
  # names, requester identities and free-form specification maps.
  sqs_managed_sse_enabled = var.sqs_managed_sse_enabled

  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  tags = var.tags
}

# Queue policy. An SQS queue policy is an additive allow, so it grants nothing
# that a same-account role's identity policy does not already grant. It is
# needed only for principals with no identity policy to attach: an AWS service
# principal, or a principal in another account.
#
# Two constraints apply to any ARN passed here:
#
#   - SQS validates principals when the policy is set, so a role that does not
#     exist yet fails the apply with "InvalidAttributeValue: Invalid value for
#     the parameter Policy". A queue cannot name a role created by a stack that
#     applies later.
#   - Service principals need aws:SourceAccount, or any account's state machine
#     could send to this queue.
#
# All three principal lists default to empty, and no policy is created when they
# all are.
data "aws_iam_policy_document" "queue" {
  count = local.create_queue_policy ? 1 : 0

  dynamic "statement" {
    for_each = length(var.producer_role_arns) > 0 ? [1] : []

    content {
      sid       = "AllowProducersToSend"
      actions   = ["sqs:SendMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes"]
      resources = [aws_sqs_queue.this.arn]

      principals {
        type        = "AWS"
        identifiers = var.producer_role_arns
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.producer_service_principals) > 0 ? [1] : []

    content {
      sid       = "AllowServicesToSend"
      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.this.arn]

      principals {
        type        = "Service"
        identifiers = var.producer_service_principals
      }

      # Confused-deputy guard: restricts the service principal to state machines
      # in this account.
      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.consumer_role_arns) > 0 ? [1] : []

    content {
      sid = "AllowConsumersToReceive"
      actions = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:GetQueueUrl",
        "sqs:GetQueueAttributes",
      ]
      resources = [aws_sqs_queue.this.arn]

      principals {
        type        = "AWS"
        identifiers = var.consumer_role_arns
      }
    }
  }
}

resource "aws_sqs_queue_policy" "this" {
  count = local.create_queue_policy ? 1 : 0

  queue_url = aws_sqs_queue.this.id
  policy    = data.aws_iam_policy_document.queue[0].json
}

# A message reaching the dead-letter queue has already exhausted the redrive
# limit and will not be retried, so its arrival is the whole signal and the
# threshold is one message rather than a rate.
#
# ApproximateNumberOfMessagesVisible is a gauge, so the alarm stays in ALARM
# until the queue is drained. Missing data is not breaching because SQS
# publishes no datapoint for an idle queue.
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  count = var.enable_dlq && var.enable_dlq_alarm ? 1 : 0

  alarm_name = "${var.queue_name}-dlq-not-empty"
  alarm_description = join(" ", [
    "Messages are sitting in ${aws_sqs_queue.dlq[0].name}.",
    "Each exhausted the redrive limit of ${var.max_receive_count} and will not be retried.",
    "Read them before the ${floor(var.dlq_message_retention_seconds / 86400)}-day retention expires.",
  ])

  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  dimensions  = { QueueName = aws_sqs_queue.dlq[0].name }

  statistic           = "Maximum"
  period              = var.dlq_alarm_period
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = var.tags
}
