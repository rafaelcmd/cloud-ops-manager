# A notification topic and its subscriptions. This is the platform's alert
# channel: CloudWatch alarms, such as the dead-letter queue alarms raised by the
# sqs module, publish here.
#
# The topic is a stable address that alarms reference by ARN, while an email
# subscription must be confirmed by a human. Recreating the topic invalidates
# every confirmation, so the topic is kept even with nothing subscribed to it.

resource "aws_sns_topic" "this" {
  name = var.name

  # Alarm payloads are operational metadata rather than secrets. Pass a CMK
  # where the topic will carry anything more sensitive.
  kms_master_key_id = var.kms_master_key_id

  tags = var.tags
}

# Keyed by a caller-chosen label rather than by the endpoint. for_each keys must
# be known at plan time, and an endpoint often is not: a queue or function
# created in the same apply has no ARN until it exists. Deriving the key from
# the endpoint fails with "the for_each value depends on resource attributes
# that cannot be determined until apply". A stable label also keeps unrelated
# subscriptions untouched when one is added or removed.
#
# An email subscription stays "pending confirmation" until the recipient clicks
# the link AWS mails them. A plan does not report that it is still pending, so
# check `aws sns list-subscriptions-by-topic` if alerts are not arriving.
resource "aws_sns_topic_subscription" "this" {
  for_each = var.subscriptions

  topic_arn = aws_sns_topic.this.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint
}

# A topic policy is created only when publishers are named. CloudWatch alarms in
# this account publish through the account's own permissions and need no entry;
# this exists for other AWS services and other accounts.
data "aws_iam_policy_document" "topic" {
  count = length(var.publisher_service_principals) > 0 ? 1 : 0

  statement {
    sid       = "AllowServicesToPublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this.arn]

    principals {
      type        = "Service"
      identifiers = var.publisher_service_principals
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_sns_topic_policy" "this" {
  count = length(var.publisher_service_principals) > 0 ? 1 : 0

  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.topic[0].json
}
