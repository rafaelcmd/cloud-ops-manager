# =============================================================================
# PROVISIONER IRSA
# The provisioner consumer's IAM role and the ServiceAccount its Deployment
# binds to (k8s/provisioner/deployment.yaml).
#
# This is the whole of the provisioner's AWS footprint today: the queue it reads
# and the cluster it runs on are owned by the `api` component, and it reaches
# both by name through SSM. The stack exists so that the service owns its own
# identity — a permission the consumer needs is added here, in the service's own
# component, rather than in the stack that happens to own the cluster.
# =============================================================================

data "aws_iam_policy_document" "provisioner" {
  # SSM: the consumer resolves the queue URL from
  # /INTERNAL_DEVELOPER_PLATFORM/PROVISIONER_QUEUE_URL at startup.
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/INTERNAL_DEVELOPER_PLATFORM/*",
    ]
  }

  # SQS: consume side of the provisioning queue (the API holds the send side).
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [data.aws_ssm_parameter.provisioner_queue_arn.value]
  }
}

module "irsa" {
  source = "../../../modules/aws/irsa"

  role_name          = "${var.cluster_name}-provisioner"
  policy_description = "Permissions for the internal-developer-platform provisioner pod"
  policy_json        = data.aws_iam_policy_document.provisioner.json

  oidc_provider_arn = data.aws_ssm_parameter.eks_oidc_provider_arn.value
  oidc_provider_url = data.aws_ssm_parameter.eks_oidc_provider_url.value

  namespace            = local.service_account_namespace
  service_account_name = local.service_account_name

  tags = local.tags
}
