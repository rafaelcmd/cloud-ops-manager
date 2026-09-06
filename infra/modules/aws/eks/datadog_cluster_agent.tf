# Datadog Cluster Agent and Fargate sidecar injection, which give Datadog's
# Kubernetes Explorer a live view of the cluster.
#
# The Cluster Agent is a single-replica Deployment that reads the Kubernetes API
# for cluster-scoped objects and unscheduled pods. It cannot report the live
# status of running pods. On Fargate that requires a datadog-agent sidecar in
# each application pod, because a DaemonSet cannot run there. The Cluster
# Agent's Admission Controller injects that sidecar into any pod labeled
# `agent.datadoghq.com/sidecar: fargate`; without it the Explorer freezes pods
# at their last reported state, typically Pending or Terminating.
#
# The injected sidecar resolves a secret named `datadog-secret`, with keys
# `api-key` and `token`, in the application pod's own namespace. That convention
# is why the secret is copied per namespace below. `token` is the shared Cluster
# Agent auth token the sidecar uses to forward orchestrator data.
#
# This path carries cluster inventory only. Application traces, metrics and logs
# go from the services to the OTel Collector over OTLP; see otel_collector.tf.

resource "kubernetes_namespace" "datadog" {
  count = var.install_datadog_cluster_agent ? 1 : 0

  metadata {
    name = var.datadog_cluster_agent_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_fargate_profile.this]
}

# Shared auth token between the Cluster Agent and the injected sidecars.
# Generated here rather than by the chart so it can be replicated into the
# application namespaces.
resource "random_password" "datadog_cluster_agent_token" {
  count = var.install_datadog_cluster_agent ? 1 : 0

  length  = 32
  special = false
}

# Secret consumed by the chart itself (apiKeyExistingSecret +
# clusterAgent.tokenExistingSecret) in the release namespace.
resource "kubernetes_secret" "datadog_secret" {
  count = var.install_datadog_cluster_agent ? 1 : 0

  metadata {
    name      = "datadog-secret"
    namespace = kubernetes_namespace.datadog[0].metadata[0].name
  }

  data = {
    api-key = var.datadog_api_key
    token   = random_password.datadog_cluster_agent_token[0].result
  }

  type = "Opaque"
}

# Copies of the secret in every namespace hosting sidecar-labeled pods. The
# injected container's secretKeyRef only resolves within its own namespace.
resource "kubernetes_secret" "datadog_secret_sidecar" {
  for_each = var.install_datadog_cluster_agent ? toset(var.datadog_sidecar_namespaces) : toset([])

  metadata {
    name      = "datadog-secret"
    namespace = each.value
  }

  data = {
    api-key = var.datadog_api_key
    token   = random_password.datadog_cluster_agent_token[0].result
  }

  type = "Opaque"
}

# The injected sidecar queries the local kubelet using the application pod's own
# ServiceAccount token, so every ServiceAccount behind a labeled pod needs
# kubelet-read access. Rules follow Datadog's EKS Fargate documentation.
resource "kubernetes_cluster_role" "datadog_sidecar" {
  count = var.install_datadog_cluster_agent && length(var.datadog_sidecar_service_accounts) > 0 ? 1 : 0

  metadata {
    name = "datadog-fargate-sidecar"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "namespaces", "endpoints"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/metrics", "nodes/spec", "nodes/stats", "nodes/proxy", "nodes/pods", "nodes/healthz"]
    verbs      = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "datadog_sidecar" {
  count = var.install_datadog_cluster_agent && length(var.datadog_sidecar_service_accounts) > 0 ? 1 : 0

  metadata {
    name = "datadog-fargate-sidecar"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.datadog_sidecar[0].metadata[0].name
  }

  dynamic "subject" {
    for_each = var.datadog_sidecar_service_accounts
    content {
      kind      = "ServiceAccount"
      name      = subject.value.name
      namespace = subject.value.namespace
    }
  }
}

resource "helm_release" "datadog" {
  count = var.install_datadog_cluster_agent ? 1 : 0

  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = kubernetes_namespace.datadog[0].metadata[0].name
  version    = var.datadog_chart_version

  # Every rescheduled pod on Fargate waits on a fresh microVM, 1 to 3 minutes
  # each, which makes the 5-minute default too tight for a rollout that moves
  # several Deployments.
  timeout = 600

  # Fargate layout: no DaemonSet, since Fargate cannot run one; a single-replica
  # Cluster Agent; and the orchestrator explorer enabled for live pod inventory.
  set = [
    {
      name  = "datadog.apiKeyExistingSecret"
      value = kubernetes_secret.datadog_secret[0].metadata[0].name
    },
    # The bundled datadog-operator subchart does not inherit
    # datadog.apiKeyExistingSecret. With its own value unset it falls back to a
    # secret named `<release>-api-key`, which this configuration never creates,
    # so it must be pointed at the same secret explicitly.
    {
      name  = "operator.apiKeyExistingSecret"
      value = kubernetes_secret.datadog_secret[0].metadata[0].name
    },
    {
      name  = "datadog.clusterName"
      value = aws_eks_cluster.this.name
    },
    {
      name  = "datadog.site"
      value = "datadoghq.com"
    },
    {
      name  = "datadog.orchestratorExplorer.enabled"
      value = "true"
    },
    # The bundled kube-state-metrics (v1.9.8) uses a 2019-era client-go and
    # floods the logs with "Failed to list *v1beta1.X" on current EKS versions.
    # The Cluster Agent's kubernetes_state_core check, enabled by default in
    # chart 3.x, reports the same metrics in-process without a separate pod.
    {
      name  = "datadog.kubeStateMetricsEnabled"
      value = "false"
    },
    {
      name  = "agents.enabled"
      value = "false"
    },
    {
      name  = "clusterAgent.enabled"
      value = "true"
    },
    {
      name  = "clusterAgent.replicas"
      value = "1"
    },
    # A fixed token rather than a chart-generated one, so sidecars in the
    # application namespaces can authenticate with the replicated secret.
    {
      name  = "clusterAgent.tokenExistingSecret"
      value = kubernetes_secret.datadog_secret[0].metadata[0].name
    },
    # The Admission Controller webhook injects the datadog-agent sidecar into
    # pods labeled `agent.datadoghq.com/sidecar: fargate` at creation time. The
    # `fargate` provider preset wires DD_EKS_FARGATE and the Cluster Agent
    # connection used to forward orchestrator data.
    {
      name  = "clusterAgent.admissionController.agentSidecarInjection.enabled"
      value = "true"
    },
    {
      name  = "clusterAgent.admissionController.agentSidecarInjection.provider"
      value = "fargate"
    },
    {
      name  = "clusterChecksRunner.enabled"
      value = "false"
    },
  ]

  depends_on = [
    aws_eks_fargate_profile.this,
    kubernetes_secret.datadog_secret,
  ]
}
