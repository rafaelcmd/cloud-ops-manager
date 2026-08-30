# =============================================================================
# LOG DELIVERY — logs reach Datadog through the OTel Collector, not CloudWatch
#
# Logs now travel the vendor-agnostic seam: services emit OTLP -> the OTel
# Collector (k8s/otel-collector) -> the Collector's `datadog` exporter. The old
# path (Fargate Fluent Bit -> this CloudWatch log group -> Datadog Lambda
# forwarder) is retired to stop double-ingestion and the vendor coupling of
# logs; the subscription filter and forwarder Lambda that made it work are gone.
#
# The Fargate pod log group itself is KEPT (EKS module, enable_fargate_logging =
# true) as a vendor-neutral, break-glass archive: it still captures pod stdout —
# including very-early crash output an app can't get onto OTLP — without shipping
# anything to a specific backend.
# =============================================================================

# =============================================================================
# ALERTING — reusable notification channel
# The SNS topic + email subscription are the AWS-native alert channel, kept so
# any out-of-band alarm can publish here without re-confirming the email.
#
# NOTE: the two alarms that watched the Datadog forwarder Lambda were removed
# with the forwarder. The equivalent health signal for the new path is the OTel
# Collector's own export metrics (otelcol_exporter_send_failed_log_records /
# _sent_log_records on :8888) — alarm on those from the Prometheus/monitoring
# side and point them at this topic. See follow-up.
# =============================================================================

resource "aws_sns_topic" "observability_alerts" {
  name = "${var.project}-${var.environment}-observability-alerts"
  tags = local.tags
}

resource "aws_sns_topic_subscription" "observability_alerts_email" {
  count = var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.observability_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
