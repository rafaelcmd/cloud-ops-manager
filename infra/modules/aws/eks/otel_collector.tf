# Prerequisites for the OpenTelemetry Collector, which is the single egress
# point for the platform's traces, metrics and logs. Services emit OTLP to the
# Collector and the Collector forwards to the observability vendor, so swapping
# vendors is a Collector config change rather than a change to every service.
#
# The Collector workload itself (Deployment, Service, ConfigMap, RBAC) is raw
# manifests in /k8s/otel-collector. Only the pieces that depend on cluster
# identity are Terraform-owned:
#
#   1. The observability namespace, which fargate.tf also adds to the Fargate
#      profile so the pod can schedule.
#   2. An IRSA-annotated ServiceAccount.
#   3. A copy of the Datadog API key secret, read by the datadog exporter.

resource "kubernetes_namespace" "observability" {
  count = var.install_otel_collector ? 1 : 0

  metadata {
    name = var.otel_collector_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_fargate_profile.this]
}

# Amazon Managed Prometheus remote-write permission, attached only when an AMP
# workspace ARN is supplied.
data "aws_iam_policy_document" "otel_collector_amp" {
  count = var.install_otel_collector && var.amp_workspace_arn != null ? 1 : 0

  statement {
    actions   = ["aps:RemoteWrite"]
    resources = [var.amp_workspace_arn]
  }
}

# Role, trust relationship and the annotated ServiceAccount the Collector
# Deployment binds to. With no AMP workspace the role is created with no
# permissions attached, which is intended: the datadog exporter needs no AWS
# credentials, and having the identity in place makes adding AMP remote write a
# configuration-only change.
#
# create_policy keys off the variable rather than off whether the document came
# out null, because the module decides how many policies to build before it can
# read one. See modules/aws/irsa.
module "otel_collector_irsa" {
  count  = var.install_otel_collector ? 1 : 0
  source = "../irsa"

  role_name          = "${var.cluster_name}-otel-collector"
  create_policy      = var.amp_workspace_arn != null
  policy_name        = "${var.cluster_name}-otel-collector-amp"
  policy_description = "Allow the OTel Collector to remote-write to Amazon Managed Prometheus"
  policy_json        = one(data.aws_iam_policy_document.otel_collector_amp[*].json)

  oidc_provider_arn = aws_iam_openid_connect_provider.cluster.arn
  oidc_provider_url = replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")

  namespace            = kubernetes_namespace.observability[0].metadata[0].name
  service_account_name = var.otel_collector_service_account

  service_account_labels = {
    "app.kubernetes.io/name" = "otel-collector"
  }

  tags = local.common_tags
}

# Read by the Collector's datadog exporter. Fixed name, because the manifests in
# /k8s/otel-collector reference it.
resource "kubernetes_secret" "otel_datadog_api_key" {
  count = var.install_otel_collector ? 1 : 0

  metadata {
    name      = "datadog-api-key"
    namespace = kubernetes_namespace.observability[0].metadata[0].name
  }

  data = {
    api-key = var.datadog_api_key
  }

  type = "Opaque"
}
