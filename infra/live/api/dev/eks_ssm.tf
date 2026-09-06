# The cluster's cross-stack contract. This stack owns the cluster, but every
# other service stack needs to mint IRSA roles against it and reach its API
# server. Publishing the coordinates here keeps that decoupled: a consumer reads
# a known SSM path instead of this workspace's state.
#
# None of these values are secret. The CA certificate is public by definition
# and the OIDC issuer URL is discoverable from the cluster.

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

# Published without the https:// scheme, which is the form an IRSA trust policy
# condition key requires ("<issuer>:sub"), so no consumer has to strip it.
resource "aws_ssm_parameter" "eks_oidc_provider_url" {
  name  = "/idp/shared/eks/oidc_provider_url"
  type  = "String"
  value = module.eks.oidc_provider_url
  tags  = local.tags
}
