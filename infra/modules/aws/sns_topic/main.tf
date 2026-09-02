# =============================================================================
# SNS TOPIC
#
# A notification topic and its subscriptions — the AWS-native alert channel that
# CloudWatch alarms publish to.
#
# The topic and the subscriptions are separate on purpose: the topic is a stable
# address that alarms reference, while an email subscription has to be confirmed
# by a human clicking a link. Recreating the topic would invalidate every
# confirmation, so keep the topic even when there is nothing subscribed to it.
# =============================================================================

resource "aws_sns_topic" "this" {
  name = var.name

  # Alarm payloads are operational metadata rather than secrets, so the
  # AWS-managed key is the sensible default; pass a CMK where the topic will
  # carry anything more sensitive.
  kms_master_key_id = var.kms_master_key_id

  tags = var.tags
}

# Terraform records an email subscription as "pending confirmation" until the
# recipient clicks the link in the mail AWS sends. It never becomes active on
# its own, and a plan will not tell you it is still pending — check the console
# or `aws sns list-subscriptions-by-topic` if alerts are not arriving.
# Keyed by the caller's own label rather than by the endpoint. for_each keys must
# be known at plan time, and an endpoint frequently is not — an SQS queue or a
# Lambda created in the same apply has no ARN until it exists. Deriving the key
# from the endpoint fails those callers with "the for_each value depends on
# resource attributes that cannot be determined until apply".
#
# A stable label also means adding or removing one subscription leaves the others
# untouched, which matters for email: a recreated subscription has to be
# confirmed again by the recipient.
resource "aws_sns_topic_subscription" "this" {
  for_each = var.subscriptions

  topic_arn = aws_sns_topic.this.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint
}

# A topic policy is only created when publishers are named. Alarms in this
# account need no policy — CloudWatch publishes through the account's own
# permissions — so this is for services and other accounts.
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
