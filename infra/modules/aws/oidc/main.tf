# An IAM OIDC provider and the first role that trusts it. This is how CI
# authenticates to AWS: a GitHub Actions job exchanges its OIDC token for
# temporary credentials, so no long-lived access key exists in any secret store.
#
# An account holds only one provider per issuer URL, so this module runs once
# per issuer. Additional roles on the same issuer use modules/aws/oidc_role,
# which attaches to the provider this module already created.
#
# The trust conditions are the entire security boundary: string_equals and
# string_like decide which repository, branch and environment may assume the
# role. See live/shared/iam-github-oidc.

resource "aws_iam_openid_connect_provider" "this" {
  url             = var.url
  client_id_list  = var.client_id_list
  thumbprint_list = [var.thumbprint]
  tags            = var.tags
}

resource "aws_iam_role" "this" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = aws_iam_openid_connect_provider.this.arn
        }
        Condition = {
          StringEquals = var.string_equals
          StringLike   = var.string_like
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  count      = length(var.policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = var.policy_arns[count.index]
}
