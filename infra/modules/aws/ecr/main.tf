# One container repository plus the lifecycle policy that bounds its size, and
# the SSM parameter CI resolves to know where to push. Every platform service
# image lives in a repository created by this module.

resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}

# Published so the deploy workflows resolve the registry URL from a known path
# rather than reconstructing it from the account id and region.
resource "aws_ssm_parameter" "repository_url" {
  name  = "/${var.project}/${var.environment}/ecr/${var.repository_name}/repository_url"
  type  = "String"
  value = aws_ecr_repository.this.repository_url

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
