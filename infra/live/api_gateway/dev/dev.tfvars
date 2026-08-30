project      = "internal-developer-platform"
environment  = "dev"
aws_region   = "us-east-1"
service_name = "resource-provisioner-api"
api_version  = "v1"

# API NLB values published to SSM by the api stack.
api_nlb_arn_ssm_parameter_name = "/internal-developer-platform/provisioner-api/nlb/arn"
api_nlb_dns_ssm_parameter_name = "/internal-developer-platform/provisioner-api/nlb/dns_name"

api_gateway_name                 = "internal-developer-platform-api"
api_gateway_description          = "Internal Developer Platform Provisioner API Gateway"
api_gateway_stage_name           = "dev"
api_gateway_auto_deploy          = true
vpc_link_name                    = "internal-developer-platform-vpc-link"
integration_timeout_ms           = 29000
throttle_rate_limit              = 1000
throttle_burst_limit             = 2000
cors_allow_credentials           = false
cors_allow_headers               = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token"]
cors_allow_methods               = ["GET", "POST", "OPTIONS"]
cors_allow_origins               = ["*"]
cors_expose_headers              = []
cors_max_age                     = 86400
api_gateway_log_retention_days   = 7
api_gateway_logging_level        = "INFO"
api_gateway_metrics_enabled      = true
api_gateway_data_trace_enabled   = false
api_gateway_xray_tracing_enabled = true

# WAF Configuration
enable_waf                = true
waf_rate_limit_requests   = 2000
waf_max_request_body_size = 10240
waf_common_rules_excluded = []
waf_enable_logging        = true
waf_log_retention_days    = 7
