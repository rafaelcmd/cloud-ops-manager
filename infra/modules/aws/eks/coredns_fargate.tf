# EKS ships CoreDNS annotated eks.amazonaws.com/compute-type: ec2, which stops
# the Fargate scheduler from picking the pods up. On a cluster with no node
# groups that leaves cluster DNS permanently unscheduled, so the annotation is
# stripped on apply.

resource "kubernetes_annotations" "coredns_remove_ec2_compute_type" {
  api_version = "apps/v1"
  kind        = "Deployment"

  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }

  template_annotations = {
    "eks.amazonaws.com/compute-type" = null
  }

  force = true

  depends_on = [
    aws_eks_fargate_profile.this,
  ]
}
