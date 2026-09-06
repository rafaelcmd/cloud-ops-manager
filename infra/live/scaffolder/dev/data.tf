# Everything this stack needs from its siblings, read from SSM rather than from
# their state, so it never needs access to another workspace's state file.

data "aws_caller_identity" "current" {}

# Cluster coordinates, published by the api component which owns the cluster
# (live/api/dev/eks_ssm.tf).
data "aws_ssm_parameter" "eks_cluster_name" {
  name = "/idp/shared/eks/cluster_name"
}

data "aws_ssm_parameter" "eks_cluster_endpoint" {
  name = "/idp/shared/eks/cluster_endpoint"
}

data "aws_ssm_parameter" "eks_cluster_ca" {
  name = "/idp/shared/eks/cluster_certificate_authority_data"
}

data "aws_ssm_parameter" "eks_oidc_provider_arn" {
  name = "/idp/shared/eks/oidc_provider_arn"
}

data "aws_ssm_parameter" "eks_oidc_provider_url" {
  name = "/idp/shared/eks/oidc_provider_url"
}

# The platform's alert channel, owned by the api component. Read rather than
# re-created: an SNS email subscription must be confirmed by a human, so a
# second topic would cost the same recipient another confirmation.
data "aws_ssm_parameter" "observability_alerts_topic_arn" {
  name = "/idp/shared/observability/alerts_topic_arn"
}
