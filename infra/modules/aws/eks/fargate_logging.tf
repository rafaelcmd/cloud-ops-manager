# Pod log routing on Fargate. The Fargate data plane runs a managed Fluent Bit
# per pod, configured through the `aws-observability` ConfigMap below, which
# routes pod stdout and stderr to a single CloudWatch log group. This avoids a
# log-collection sidecar in every pod.

resource "aws_cloudwatch_log_group" "fargate_pods" {
  count = var.enable_fargate_logging ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/fargate-pods"
  retention_in_days = var.fargate_log_retention_days
  tags              = local.common_tags
}

# The managed AmazonEKSFargatePodExecutionRolePolicy covers ECR pulls but not
# CloudWatch Logs writes, so the execution role needs this policy as well.
data "aws_iam_policy_document" "fargate_logging" {
  count = var.enable_fargate_logging ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      aws_cloudwatch_log_group.fargate_pods[0].arn,
      "${aws_cloudwatch_log_group.fargate_pods[0].arn}:*",
    ]
  }
}

resource "aws_iam_policy" "fargate_logging" {
  count = var.enable_fargate_logging ? 1 : 0

  name        = "${var.cluster_name}-fargate-logging"
  description = "Allow Fargate pods' execution role to write to the pod log group"
  policy      = data.aws_iam_policy_document.fargate_logging[0].json
  tags        = local.common_tags
}

resource "aws_iam_role_policy_attachment" "fargate_logging" {
  count = var.enable_fargate_logging ? 1 : 0

  role       = aws_iam_role.fargate.name
  policy_arn = aws_iam_policy.fargate_logging[0].arn
}

# Fixed name: the Fargate data plane looks for the logging ConfigMap in this
# namespace specifically. No pods run here; it is only a configuration channel.
resource "kubernetes_namespace" "aws_observability" {
  count = var.enable_fargate_logging ? 1 : 0

  metadata {
    name = "aws-observability"
    labels = {
      "aws-observability"            = "enabled"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_cluster.this]
}

resource "kubernetes_config_map" "aws_logging" {
  count = var.enable_fargate_logging ? 1 : 0

  metadata {
    name      = "aws-logging"
    namespace = kubernetes_namespace.aws_observability[0].metadata[0].name
  }

  data = {
    "output.conf" = <<-EOT
      [OUTPUT]
          Name              cloudwatch_logs
          Match             *
          region            ${var.aws_region}
          log_group_name    ${aws_cloudwatch_log_group.fargate_pods[0].name}
          log_stream_prefix fargate-
          auto_create_group false
    EOT
  }

  depends_on = [aws_iam_role_policy_attachment.fargate_logging]
}
