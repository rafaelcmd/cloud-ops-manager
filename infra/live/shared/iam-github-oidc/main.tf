# The trust anchor for CI. GitHub Actions jobs exchange an OIDC token for
# temporary AWS credentials here, which is why no AWS access key exists in any
# repository secret.
#
# This is a bootstrap stack: every other stack's pipeline depends on it, so it
# is applied by hand and is deliberately not part of the orchestrator chain.
#
# This file creates the OIDC provider itself, which an account holds exactly one
# of per issuer. The roles that use it are in roles.tf (one per Terraform
# component) and plan_role.tf (read-only, for pull requests), with their
# permissions split across the policy_*.tf files.

data "tls_certificate" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"
}

module "github_actions_oidc" {
  source         = "../../../modules/aws/oidc"
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint     = data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint
  role_name      = var.github_role_name
  string_equals = {
    "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
  }
  string_like = {
    "token.actions.githubusercontent.com:sub" = var.github_allowed_subs
  }
  policy_arns = var.github_policy_arns
  tags        = local.tags
}
