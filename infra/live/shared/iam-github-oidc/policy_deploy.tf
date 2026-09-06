# Workload deploy workflows (api, provisioner, otel-collector, redis).
# These run no Terraform: they read a handful of SSM parameters, push images,
# and apply Kubernetes manifests. Cluster authorization is separate: the role
# must also appear in cluster_admin_principal_arns so EKS grants it kubectl
# access through an access entry.

resource "aws_iam_policy" "pipeline_deploy" {
  name        = "${var.project}-${var.environment}-pipeline-deploy-policy"
  description = "Pipeline policy for workload deploys (SSM reads, ECR push, cluster auth)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadDeployParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "*"
      },
      {
        Sid    = "PushWorkloadImages"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Sid    = "ClusterAuthForKubectl"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}
