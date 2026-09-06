# An IAM role assumable through an OIDC provider that already exists.
#
# Distinct from modules/aws/oidc, which creates the provider and one role. An
# account holds only one provider per issuer URL, so every role beyond the first
# attaches to the provider that module created. This is what gives each
# Terraform component its own github-actions-tf-<component> role instead of one
# shared role across every stack.

resource "aws_iam_role" "this" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = var.oidc_provider_arn
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

# Indexed by count rather than for_each. The ARNs are created in the same apply,
# so their values are unknown at plan time and cannot form set keys.
resource "aws_iam_role_policy_attachment" "this" {
  count = length(var.policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = var.policy_arns[count.index]
}
