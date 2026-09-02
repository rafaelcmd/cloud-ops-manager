# =============================================================================
# SQS QUEUE
#
# One work queue, its dead-letter queue, and a resource policy naming the
# principals allowed on each side.
#
# Consumers resolve queues by name, so the caller owns the name; everything
# else has a default that is safe for a work queue and can be overridden where
# a service needs something different.
# =============================================================================

data "aws_caller_identity" "current" {}

# The dead-letter queue exists so that a message the consumer can never handle
# stops being redelivered forever. Without one, a payload that fails to parse
# comes back every visibility timeout until it ages out of retention — for days,
# at the consumer's expense, drowning real traffic in the same log line.
#
# It retains longer than the main queue on purpose: the DLQ is what someone
# reads days later to work out what broke.
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

  # Queues created through the API — which is what Terraform does — are not
  # encrypted by default; only ones created in the console are. These messages
  # carry application names, requester identities and free-form specification
  # maps, so they are worth encrypting at rest. The SQS-owned key costs nothing,
  # unlike a customer-managed KMS key.
  sqs_managed_sse_enabled = var.sqs_managed_sse_enabled

  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  tags = var.tags
}

# =============================================================================
# QUEUE POLICY
#
# For principals that cannot be authorized any other way. An SQS queue policy is
# an additive allow, not a restriction, so for a role in this account it adds
# nothing that the role's own identity policy does not already grant. Reach for
# it when the sender has no identity policy to attach:
#
#   - an AWS service principal (states.amazonaws.com delivering task tokens)
#   - a principal in another account
#
# TWO THINGS TO KNOW BEFORE PASSING AN ARN HERE:
#
# SQS validates principals when the policy is set. Naming a role that does not
# exist yet fails with "InvalidAttributeValue: Invalid value for the parameter
# Policy" — so a queue in one stack cannot name a role created by a stack that
# applies later, however stable that role's name is.
#
# aws:SourceAccount is what makes a service principal safe: without it, any
# account's state machine could send to this queue.
#
# All three lists are empty by default and no policy is created when they all
# are, which is the right outcome for a queue whose counterparties are ordinary
# same-account roles.
# =============================================================================

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

  # A service principal — Step Functions delivering task tokens, say — is not an
  # ARN in this account, so aws:SourceAccount is what stops another account's
  # state machine from sending here. The confused-deputy guard.
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

# =============================================================================
# DEAD-LETTER QUEUE ALARM
#
# A dead-letter queue nobody watches is a slower way to lose a message. Anything
# that lands here has already been retried maxReceiveCount times and will not be
# retried again, so the arrival is the whole signal — hence a threshold of one
# message rather than a rate.
#
# ApproximateNumberOfMessagesVisible is a gauge, not a counter: it keeps
# reporting while the message sits there, so the alarm stays ON until the queue
# is drained. That is the intended behaviour — it should not clear itself while
# a failed request is still unexamined.
#
# treat_missing_data is "notBreaching" because SQS publishes no datapoint for a
# queue with no traffic, and an empty dead-letter queue is the good case.
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  count = var.enable_dlq && var.enable_dlq_alarm ? 1 : 0

  alarm_name = "${var.queue_name}-dlq-not-empty"
  # Read by whoever the alarm wakes, so it says what happened and what to do —
  # not just which metric moved.
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
