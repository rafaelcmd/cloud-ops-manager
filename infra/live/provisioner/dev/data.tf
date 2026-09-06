# Everything this stack needs from its siblings, read from SSM rather than from
# their state, so it never needs access to another workspace's state file.

# Cluster coordinates, published by the api component which owns the cluster
# (live/api/dev/eks_ssm.tf). The endpoint and CA configure the kubernetes
# provider; the OIDC pair is what the IRSA trust policy is built on.
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

# The provisioning queue, also owned by the api component. The ARN rather than
# the URL, because an IAM policy is written against the ARN and deriving one
# form from the other in HCL would mean hard-coding the account id.
data "aws_ssm_parameter" "provisioner_queue_arn" {
  name = "/idp/shared/provisioner/queue_arn"
}
