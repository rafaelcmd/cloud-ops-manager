# The platform's only image registry. Every service image is pushed here by CI
# and pulled by Fargate; the repository URL is published to SSM for the deploy
# workflows to resolve.

module "ecr" {
  source = "../../../modules/aws/ecr"

  repository_name = "internal-developer-platform-repo"
  project         = var.project
  environment     = var.environment
}
