# =============================================================================
# IAM Roles for Service Accounts (IRSA)
#
# Binds one Kubernetes ServiceAccount to one IAM role through a cluster's OIDC
# provider: the trust policy accepts a web identity whose `sub` claim is exactly
# that ServiceAccount, and the ServiceAccount carries the role ARN in the
# annotation EKS reads when it projects a token into the pod.
#
# The `sub` condition is scoped to a single ServiceAccount rather than to the
# namespace. Scoped to a namespace, any pod in it could assume the role, which
# would defeat arrangements like the scaffolder's — where one Deployment may read
# the GitHub App private key and its twin, in the same namespace, may not.
# =============================================================================

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  description        = var.role_description
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

# A role with no policy is a valid outcome, not a mistake: the OTel Collector
# needs an identity for its ServiceAccount but no AWS permissions until an AMP
# workspace exists to write to.
resource "aws_iam_policy" "this" {
  count = var.policy_json != null ? 1 : 0

  name        = coalesce(var.policy_name, "${var.role_name}-policy")
  description = var.policy_description
  policy      = var.policy_json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  count = var.policy_json != null ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this[0].arn
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = toset(var.policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# Optional because some ServiceAccounts are owned by the chart that installs the
# workload rather than by Terraform.
resource "kubernetes_service_account" "this" {
  count = var.create_service_account ? 1 : 0

  metadata {
    name      = var.service_account_name
    namespace = var.namespace

    # The role-arn annotation is the whole point of the resource, so it is
    # merged last and cannot be overridden by a caller.
    annotations = merge(
      var.service_account_annotations,
      { "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn },
    )

    labels = merge(
      {
        "app.kubernetes.io/name"       = var.service_account_name
        "app.kubernetes.io/managed-by" = "terraform"
      },
      var.service_account_labels,
    )
  }
}
