# =============================================================================
# API IRSA
# The API pod's IAM role and the ServiceAccount its Deployment binds to
# (k8s/api/deployment.yaml). The role and the trust relationship come from
# modules/aws/irsa; what stays here is the part that is specific to this
# pod — which AWS resources it may touch.
# =============================================================================

locals {
  api_service_account_name      = "internal-developer-platform-api"
  api_service_account_namespace = "default"
}

data "aws_iam_policy_document" "api" {
  # SSM: the API reads its runtime config from two prefixes —
  #   /INTERNAL_DEVELOPER_PLATFORM/*   (queue URL, Redis addr)
  #   /idp/shared/identity/*           (Cognito user-pool / client IDs)
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/INTERNAL_DEVELOPER_PLATFORM/*",
      "arn:aws:ssm:${var.aws_region}:*:parameter/idp/shared/identity/*",
    ]
  }

  # SQS: the API publishes provisioning requests to the provisioner queue.
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [module.sqs.queue_arn]
  }

  # Cognito: signup/login flow. User pool ARN is read from SSM (published by
  # shared/identity) instead of terraform_remote_state, matching the rest of
  # the SSM-decoupled graph.
  statement {
    actions = [
      "cognito-idp:SignUp",
      "cognito-idp:ConfirmSignUp",
      "cognito-idp:InitiateAuth",
    ]
    resources = [data.aws_ssm_parameter.cognito_user_pool_arn.value]
  }
}

module "irsa" {
  source = "../../../modules/aws/irsa"

  role_name          = "${var.cluster_name}-api"
  policy_description = "Permissions for the internal-developer-platform API pod"
  policy_json        = data.aws_iam_policy_document.api.json

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  namespace            = local.api_service_account_namespace
  service_account_name = local.api_service_account_name

  tags = local.tags

  depends_on = [module.eks]
}
