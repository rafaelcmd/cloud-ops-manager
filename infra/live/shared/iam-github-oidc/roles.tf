# Per-component pipeline roles.
#
# Each Terraform component assumes a role scoped to the services that
# component provisions, so a compromised or misbehaving run is bounded by
# the stack it belongs to rather than the account. Role names follow
# github-actions-tf-<component>; the workflows build the ARN from that
# convention plus the AWS_ACCOUNT_ID repo variable, so adding a component
# needs no new repo configuration.
#
# The trust conditions match the identities a pipeline job can present: the
# main branch ref for ungated jobs, and one entry per environment the gated
# apply/destroy jobs can run in: `dev` normally, and `dev-auto` when the
# DISABLE_DEPLOYMENT_APPROVALS repository variable is set (see
# .github/workflows/_terraform.yml). A job that names an environment presents
# `environment:<name>` as its subject instead of the ref, so an
# environment missing from this list fails AssumeRoleWithWebIdentity.
# Pull-request plans use the separate read-only role in plan_role.tf.

locals {
  pipeline_trust_subs = [
    "repo:rafaelcmd/internal-developer-platform:ref:refs/heads/main",
    "repo:rafaelcmd/internal-developer-platform:environment:dev",
    "repo:rafaelcmd/internal-developer-platform:environment:dev-auto"
  ]

  component_policy_arns = {
    vpc           = aws_iam_policy.pipeline_vpc.arn
    ecr           = aws_iam_policy.pipeline_ecr.arn
    datadog       = aws_iam_policy.pipeline_datadog.arn
    identity      = aws_iam_policy.pipeline_identity.arn
    api           = aws_iam_policy.pipeline_api.arn
    provisioner   = aws_iam_policy.pipeline_provisioner.arn
    "api-gateway" = aws_iam_policy.pipeline_api_gateway.arn
    scaffolder    = aws_iam_policy.pipeline_scaffolder.arn
  }
}

module "component_roles" {
  for_each = local.component_policy_arns

  source            = "../../../modules/aws/oidc_role"
  role_name         = "github-actions-tf-${each.key}"
  oidc_provider_arn = module.github_actions_oidc.oidc_provider_arn

  string_equals = {
    "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
  }
  string_like = {
    "token.actions.githubusercontent.com:sub" = local.pipeline_trust_subs
  }

  policy_arns = [
    aws_iam_policy.pipeline_common.arn,
    each.value
  ]

  tags = local.tags
}

module "deploy_role" {
  source            = "../../../modules/aws/oidc_role"
  role_name         = "github-actions-deploy"
  oidc_provider_arn = module.github_actions_oidc.oidc_provider_arn

  string_equals = {
    "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
  }
  string_like = {
    "token.actions.githubusercontent.com:sub" = local.pipeline_trust_subs
  }

  policy_arns = [aws_iam_policy.pipeline_deploy.arn]

  tags = local.tags
}
