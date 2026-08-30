# =============================================================================
# EKS COORDINATES → SSM
# This stack owns the cluster, but workloads deployed from other components need
# to mint IRSA roles and talk to the API server. Publishing the coordinates to
# Parameter Store keeps that decoupled: a consumer reads SSM instead of this
# workspace's state, so it never needs TFC access to it. Same contract the vpc
# and identity stacks expose.
#
# None of these are secret — the CA certificate is public by definition and the
# OIDC issuer URL is discoverable from the cluster.
# =============================================================================

resource "aws_ssm_parameter" "eks_cluster_name" {
  name  = "/idp/shared/eks/cluster_name"
  type  = "String"
  value = module.eks.cluster_name
  tags  = local.tags
}

resource "aws_ssm_parameter" "eks_cluster_endpoint" {
  name  = "/idp/shared/eks/cluster_endpoint"
  type  = "String"
  value = module.eks.cluster_endpoint
  tags  = local.tags
}

resource "aws_ssm_parameter" "eks_cluster_certificate_authority_data" {
  name  = "/idp/shared/eks/cluster_certificate_authority_data"
  type  = "String"
  value = module.eks.cluster_certificate_authority_data
  tags  = local.tags
}

resource "aws_ssm_parameter" "eks_oidc_provider_arn" {
  name  = "/idp/shared/eks/oidc_provider_arn"
  type  = "String"
  value = module.eks.oidc_provider_arn
  tags  = local.tags
}

# Without the https:// scheme, which is the form an IRSA trust policy condition
# key needs ("<issuer>:sub"). Publishing it pre-stripped stops every consumer
# from having to remember that.
resource "aws_ssm_parameter" "eks_oidc_provider_url" {
  name  = "/idp/shared/eks/oidc_provider_url"
  type  = "String"
  value = module.eks.oidc_provider_url
  tags  = local.tags
}
