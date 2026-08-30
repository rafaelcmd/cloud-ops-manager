# =============================================================================
# NLB LOOKUP (FROM SSM)
# The API NLB is Terraform-managed in the api stack and published
# to SSM so this stack stays decoupled from producer state files.
# =============================================================================

data "aws_ssm_parameter" "api_nlb_arn" {
  name = var.api_nlb_arn_ssm_parameter_name
}

data "aws_ssm_parameter" "api_nlb_dns_name" {
  name = var.api_nlb_dns_ssm_parameter_name
}

# =============================================================================
# IDENTITY LOOKUP (SSM)
# Cognito is owned by the shared/identity workspace, which publishes the user
# pool ARN to /idp/shared/identity/user_pool_arn. Reading via SSM keeps this
# workspace decoupled from the producer's state file.
# =============================================================================

data "aws_ssm_parameter" "cognito_user_pool_arn" {
  name = "/idp/shared/identity/user_pool_arn"
}
