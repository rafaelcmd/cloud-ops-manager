# The platform's identity provider. The API Gateway authorizer validates caller
# tokens against this user pool, so it is the only way a request is attributed
# to a person.
#
# It lives in its own stack (live/shared/identity) rather than inside the
# gateway stack: the API workload also needs the pool ARN, and nesting Cognito
# under the gateway made the API stack depend on a stack that already depended
# on it.

resource "aws_cognito_user_pool" "this" {
  name = var.user_pool_name

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  username_attributes = ["email"]

  auto_verified_attributes = ["email"]

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Account Confirmation"
    email_message        = "Your confirmation code is {####}"
  }

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_cognito_user_pool_client" "this" {
  name = "${var.user_pool_name}-client"

  user_pool_id = aws_cognito_user_pool.this.id

  # No client secret: a public client cannot keep one, and the gateway
  # authorizer validates the token's signature rather than the client.
  generate_secret     = false
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
}

locals {
  cognito_common_tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}

# Two SSM namespaces, one per kind of consumer.
#
# /INTERNAL_DEVELOPER_PLATFORM/* is the Terraform-to-runtime contract: the path
# the Go API reads at startup (see application.go).
resource "aws_ssm_parameter" "cognito_client_id_legacy" {
  name  = "/INTERNAL_DEVELOPER_PLATFORM/COGNITO_CLIENT_ID"
  type  = "String"
  value = aws_cognito_user_pool_client.this.id

  tags = local.cognito_common_tags
}

# /idp/shared/* is the cross-stack contract, read by sibling Terraform stacks:
# the gateway's authorizer and the API's IRSA scope. A consumer needs IAM read
# on the path and nothing from this workspace's state.
resource "aws_ssm_parameter" "user_pool_id" {
  name  = "/idp/shared/identity/user_pool_id"
  type  = "String"
  value = aws_cognito_user_pool.this.id

  tags = local.cognito_common_tags
}

resource "aws_ssm_parameter" "user_pool_arn" {
  name  = "/idp/shared/identity/user_pool_arn"
  type  = "String"
  value = aws_cognito_user_pool.this.arn

  tags = local.cognito_common_tags
}

resource "aws_ssm_parameter" "user_pool_client_id" {
  name  = "/idp/shared/identity/user_pool_client_id"
  type  = "String"
  value = aws_cognito_user_pool_client.this.id

  tags = local.cognito_common_tags
}
