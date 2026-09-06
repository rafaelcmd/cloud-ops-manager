# The platform's public edge. Everything a caller reaches goes through the
# gateway created here: WAF filters the request, a Cognito authorizer
# authenticates it, and a VPC Link forwards it to the internal NLB in front of
# the API pods.
#
# This stack owns none of those three dependencies. The NLB belongs to the api
# stack and Cognito to shared/identity; both are read from SSM in data.tf, so
# this workspace needs no access to either one's state.

module "waf" {
  source = "../../../modules/aws/waf"

  web_acl_name        = "${var.project}-${var.environment}-api-waf"
  web_acl_description = "WAF Web ACL for ${var.project} API Gateway"

  # The per-IP ceiling that bounds how much traffic one client can drive into
  # the gateway and the Fargate pods behind it.
  rate_limit_requests = var.waf_rate_limit_requests

  max_request_body_size = var.waf_max_request_body_size

  # Managed rules that misfire on this API's JSON traffic. Listing one here
  # switches it to count, so it still reports what it would have blocked.
  common_rules_excluded = var.waf_common_rules_excluded

  enable_logging     = var.waf_enable_logging
  log_retention_days = var.waf_log_retention_days

  project     = var.project
  environment = var.environment
  tags        = local.tags
}

module "api_gateway" {
  source = "../../../modules/aws/api_gateway"

  api_name        = var.api_gateway_name
  api_description = var.api_gateway_description
  aws_region      = var.aws_region

  # A REST API VPC Link targets the load balancer ARN directly, not subnets.
  # Both values are published by the api stack.
  vpc_link_name = var.vpc_link_name
  nlb_arn       = data.aws_ssm_parameter.api_nlb_arn.value
  nlb_dns_name  = data.aws_ssm_parameter.api_nlb_dns_name.value

  # The authorizer that turns a caller's token into an identity. Published by
  # shared/identity.
  cognito_user_pool_arn = data.aws_ssm_parameter.cognito_user_pool_arn.value

  stage_name  = var.api_gateway_stage_name
  api_version = var.api_version

  # Regional rather than edge-optimized: no CloudFront distribution in front, so
  # WAF associates directly with the stage.
  endpoint_type = "REGIONAL"
  # Disabled. Responses are small JSON documents, where compression costs more
  # than it saves.
  minimum_compression_size = -1

  throttle_rate_limit  = var.throttle_rate_limit
  throttle_burst_limit = var.throttle_burst_limit

  log_retention_days   = var.api_gateway_log_retention_days
  logging_level        = var.api_gateway_logging_level
  data_trace_enabled   = var.api_gateway_data_trace_enabled
  metrics_enabled      = var.api_gateway_metrics_enabled
  xray_tracing_enabled = var.api_gateway_xray_tracing_enabled

  # API Gateway's CloudWatch role is one account-wide setting. This stack claims
  # it; a second stack in this account and region must not.
  create_api_gateway_account = true

  cache_cluster_enabled = false

  enable_waf      = var.enable_waf
  waf_web_acl_arn = var.enable_waf ? module.waf.web_acl_arn : null

  project     = var.project
  environment = var.environment

  tags = local.tags
}
