resource "aws_ecr_repository" "cloud_ops_manager_ecr_repository" {
  name                 = "cloud_ops_manager_ecr_repository"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name        = "cloud-ops-manager-ecr-repository"
  }
}