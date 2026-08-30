# =============================================================================
# OPENTELEMETRY COLLECTOR — cluster-managed prerequisites
#
# The Collector workload itself (Deployment/Service/ConfigMap/RBAC) lives as raw
# manifests in /k8s/otel-collector. This file provisions the pieces that must be
# Terraform-owned because they depend on cluster identity:
#
#   1. The `observability` namespace (also auto-added to the Fargate profile in
#      fargate.tf, so the pod can schedule — Fargate has no default nodes).
#   2. An IRSA-annotated ServiceAccount. IRSA is only strictly needed once an
#      AWS-authenticated exporter is added (Amazon Managed Prometheus remote
#      write signs with SigV4); the datadog exporter needs no AWS auth. Wiring
#      the role now makes adding AMP a config-only change.
#   3. A copy of the Datadog API key secret in the observability namespace,
#      consumed by the Collector's datadog exporter.
#
# Mirrors the IRSA + ServiceAccount pattern used for the AWS Load Balancer
# Controller (aws_lb_controller.tf).
# =============================================================================

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

# -----------------------------------------------------------------------------
# IRSA ROLE + SERVICE ACCOUNT
# -----------------------------------------------------------------------------

# Amazon Managed Prometheus remote-write permission — attached only when an AMP
# workspace ARN is supplied. Until then the Collector role has no policies and
# the datadog exporter path works without any AWS permissions.
data "aws_iam_policy_document" "otel_collector_amp" {
  count = var.install_otel_collector && var.amp_workspace_arn != null ? 1 : 0

  statement {
    actions   = ["aps:RemoteWrite"]
    resources = [var.amp_workspace_arn]
  }
}

# Role, trust relationship and the annotated ServiceAccount the Collector
# Deployment binds to. Without an AMP workspace the role is created with no
# permissions attached — deliberate: the datadog exporter needs no AWS auth, and
# having the identity in place makes adding AMP a config-only change.
#
# create_policy keys off the variable, not off whether the document came out
# null: the module decides how many policies to build before it can read one.
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

# -----------------------------------------------------------------------------
# DATADOG API KEY SECRET — consumed by the Collector's datadog exporter
# -----------------------------------------------------------------------------

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
