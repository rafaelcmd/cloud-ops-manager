# The platform's identity provider. Standalone rather than nested inside the
# gateway stack: the API workload needs the user pool ARN too, and nesting
# Cognito under the gateway made the API stack depend on a stack that already
# depended on it. Consumers read /idp/shared/identity/*.

module "cognito" {
  source = "../../../modules/aws/cognito"

  user_pool_name = var.user_pool_name
  project        = var.project
  environment    = var.environment

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Workspace   = "shared/identity"
  }
}
