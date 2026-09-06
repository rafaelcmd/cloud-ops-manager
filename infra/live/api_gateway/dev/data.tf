# Everything this stack needs from its siblings, read from SSM rather than from
# their state.

# The internal NLB, owned by the api stack. The VPC Link targets its ARN; the
# DNS name is substituted into the OpenAPI document's integration URI.

data "aws_ssm_parameter" "api_nlb_arn" {
  name = var.api_nlb_arn_ssm_parameter_name
}

data "aws_ssm_parameter" "api_nlb_dns_name" {
  name = var.api_nlb_dns_ssm_parameter_name
}

# The Cognito user pool the gateway authorizer validates tokens against, owned
# by shared/identity.

data "aws_ssm_parameter" "cognito_user_pool_arn" {
  name = "/idp/shared/identity/user_pool_arn"
}
