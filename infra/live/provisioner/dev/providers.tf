provider "aws" {
  region = var.aws_region
}

# The ServiceAccount this stack creates lives in a cluster owned by another
# stack, so the provider is configured from SSM rather than from a module
# reference. The credential is minted per run with `aws eks get-token`, so
# nothing long-lived is written to state.
provider "kubernetes" {
  host                   = data.aws_ssm_parameter.eks_cluster_endpoint.value
  cluster_ca_certificate = base64decode(data.aws_ssm_parameter.eks_cluster_ca.value)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.aws_ssm_parameter.eks_cluster_name.value, "--region", var.aws_region]
  }
}
