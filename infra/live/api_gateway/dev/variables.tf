# =============================================================================
# GENERAL PROJECT CONFIGURATION
# =============================================================================

variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev) used for resource naming and tagging"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
}

variable "service_name" {
  description = "Name of the service being deployed (used for tagging)"
  type        = string
}

variable "api_version" {
  description = "API version for path-based versioning (e.g., v1, v2)"
  type        = string
  default     = "v1"
}

# =============================================================================
# LOAD BALANCER LOOKUP (SSM)
# NLB attributes are published by the api Terraform stack.
# =============================================================================

variable "api_nlb_arn_ssm_parameter_name" {
  description = "SSM parameter name containing the API NLB ARN"
  type        = string
}

variable "api_nlb_dns_ssm_parameter_name" {
  description = "SSM parameter name containing the API NLB DNS name"
  type        = string
}

# =============================================================================
# API GATEWAY CONFIGURATION
# =============================================================================

variable "api_gateway_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "api_gateway_description" {
  description = "Description of the API Gateway"
  type        = string
}

variable "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "dev"
}

variable "api_gateway_auto_deploy" {
  description = "Whether to automatically deploy API changes"
  type        = bool
}

# =============================================================================
# VPC LINK CONFIGURATION
# =============================================================================

variable "vpc_link_name" {
  description = "Name of the VPC Link"
  type        = string
}

# =============================================================================
# API GATEWAY INTEGRATION CONFIGURATION
# =============================================================================

variable "integration_timeout_ms" {
  description = "Integration timeout in milliseconds"
  type        = number
}

# =============================================================================
# API GATEWAY THROTTLING CONFIGURATION
# =============================================================================

variable "throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
}

variable "throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
}

# =============================================================================
# CORS CONFIGURATION
# =============================================================================

variable "cors_allow_credentials" {
  description = "Whether to allow credentials in CORS requests"
  type        = bool
}

variable "cors_allow_headers" {
  description = "List of allowed headers for CORS"
  type        = list(string)
}

variable "cors_allow_methods" {
  description = "List of allowed HTTP methods for CORS"
  type        = list(string)
}

variable "cors_allow_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
}

variable "cors_expose_headers" {
  description = "List of headers to expose in CORS responses"
  type        = list(string)
}

variable "cors_max_age" {
  description = "Maximum age for CORS preflight requests in seconds"
  type        = number
}

# =============================================================================
# API GATEWAY LOGGING AND MONITORING
# =============================================================================

variable "api_gateway_log_retention_days" {
  description = "CloudWatch log group retention period in days for API Gateway"
  type        = number
}

variable "api_gateway_logging_level" {
  description = "CloudWatch logging level for API Gateway (OFF, ERROR, INFO)"
  type        = string
}

variable "api_gateway_metrics_enabled" {
  description = "Whether to enable CloudWatch metrics for API Gateway"
  type        = bool
}

variable "api_gateway_data_trace_enabled" {
  description = "Whether to enable data trace for API Gateway"
  type        = bool
}

variable "api_gateway_xray_tracing_enabled" {
  description = "Whether to enable X-Ray tracing for API Gateway"
  type        = bool
}

# =============================================================================
# WAF CONFIGURATION
# =============================================================================

variable "enable_waf" {
  description = "Whether to enable WAF protection for the API Gateway"
  type        = bool
  default     = true
}

variable "waf_rate_limit_requests" {
  description = "Maximum number of requests per 5-minute period per IP"
  type        = number
  default     = 2000
}

variable "waf_max_request_body_size" {
  description = "Maximum request body size in bytes"
  type        = number
  default     = 10240
}

variable "waf_common_rules_excluded" {
  description = "List of AWS Common Rule Set rules to exclude"
  type        = list(string)
  default     = []
}

variable "waf_enable_logging" {
  description = "Enable CloudWatch logging for WAF"
  type        = bool
  default     = true
}

variable "waf_log_retention_days" {
  description = "Number of days to retain WAF logs"
  type        = number
  default     = 7
}
