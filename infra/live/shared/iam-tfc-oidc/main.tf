# The trust anchor for Terraform Cloud remote runs, the counterpart to
# iam-github-oidc.
#
# Nothing currently uses it. Terraform Cloud holds state only; runs execute on
# the GitHub runner in Local execution mode, so a stack is always applied by its
# own github-actions-tf-<component> role. This stack is retained for the remote
# execution path.

data "tls_certificate" "tfc_oidc" {
  url = "https://app.terraform.io"
}

module "tfc_oidc" {
  source         = "../../../modules/aws/oidc"
  url            = "https://app.terraform.io"
  client_id_list = ["aws.workload.identity"]
  thumbprint     = data.tls_certificate.tfc_oidc.certificates[0].sha1_fingerprint
  role_name      = var.tfc_role_name
  string_equals = {
    "app.terraform.io:aud" = "aws.workload.identity"
  }
  string_like = {
    "app.terraform.io:sub" = var.tfc_allowed_subs
  }
  policy_arns = concat(var.tfc_policy_arns, [
    aws_iam_policy.provisioner_api_infra_policy.arn,
    aws_iam_policy.provisioner_api_security_policy.arn,
    aws_iam_policy.provisioner_api_app_policy.arn,
    aws_iam_policy.provisioner_api_observability_policy.arn,
  ])
  tags = local.tags
}

