# The platform's alert channel, and the SSM parameter that publishes it.
#
# Logs do not pass through here. Services emit OTLP to the OTel Collector
# (k8s/otel-collector), which exports to Datadog, so log delivery is a
# Collector concern rather than a CloudWatch one. The Fargate pod log group is
# still enabled on the cluster as a vendor-neutral archive: it captures pod
# stdout, including early crash output a process never gets onto OTLP.
#
# The Collector's own export counters, otelcol_exporter_send_failed_log_records
# and otelcol_exporter_sent_log_records on port 8888, are the health signal for
# that path. Nothing alarms on them yet.

module "observability_alerts" {
  source = "../../../modules/aws/sns_topic"

  name = "${var.project}-${var.environment}-observability-alerts"

  # An empty notification_email leaves the topic with no subscribers. That is a
  # working state: alarms still publish, and nothing is delivered until an
  # address is set and the recipient confirms it.
  subscriptions = var.notification_email != "" ? {
    ops-email = { protocol = "email", endpoint = var.notification_email }
  } : {}

  tags = local.tags
}

# Published so sibling stacks point their alarms at this topic instead of
# creating a channel of their own, which would cost another email confirmation.
# The scaffolder's dead-letter queue alarms read it.
resource "aws_ssm_parameter" "observability_alerts_topic_arn" {
  name  = "/idp/shared/observability/alerts_topic_arn"
  type  = "String"
  value = module.observability_alerts.topic_arn

  tags = local.tags
}
