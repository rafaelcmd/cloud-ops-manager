# The API pod's IAM role and the ServiceAccount its Deployment binds to, defined
# in k8s/api/deployment.yaml.
#
# The role and its trust relationship come from modules/aws/irsa. What lives
# here is the part specific to this pod: exactly which AWS resources it may
# touch, each scoped to a concrete ARN.

locals {
  api_service_account_name      = "internal-developer-platform-api"
  api_service_account_namespace = "default"
}

data "aws_iam_policy_document" "api" {
  # The API resolves its runtime configuration at startup from two prefixes:
  # /INTERNAL_DEVELOPER_PLATFORM/* for the queue URL and Redis address, and
  # /idp/shared/identity/* for the Cognito pool and client ids.
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

  # The API's only write to the rest of the platform: it publishes provision
  # requests and returns 202. Everything downstream happens off this queue.
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [module.sqs.queue_arn]
  }

  # Signup and login. The pool ARN comes from SSM rather than from the identity
  # stack's state, like every other cross-stack value here.
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
