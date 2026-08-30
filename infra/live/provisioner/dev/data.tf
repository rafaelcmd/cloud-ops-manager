# =============================================================================
# DATA SOURCES
# Cross-workspace values come from SSM Parameter Store, published by the stacks
# that own them. No terraform_remote_state read means this workspace never needs
# access to another's state.
# =============================================================================

# EKS cluster coordinates — published by the `api` component, which owns the
# cluster (infra/live/api/dev/eks_ssm.tf). The endpoint and CA configure the
# kubernetes provider; the OIDC pair is what the IRSA trust policy is built on.
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

# The provisioning queue, also owned by the `api` component. The ARN rather than
# the URL: an IAM policy is written against the ARN, and deriving one from the
# other in HCL means hard-coding the account id.
data "aws_ssm_parameter" "provisioner_queue_arn" {
  name = "/idp/shared/provisioner/queue_arn"
}
