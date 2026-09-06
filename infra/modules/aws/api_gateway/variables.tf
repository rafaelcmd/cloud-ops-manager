variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "api_description" {
  description = "Description of the API Gateway"
  type        = string
}

variable "aws_region" {
  description = "AWS region for API Gateway"
  type        = string
}

# A REST API VPC Link targets the load balancer's ARN directly. HTTP API VPC
# Links take subnets and security groups instead, so examples written for HTTP
# APIs do not transfer.
variable "vpc_link_name" {
  description = "Name of the VPC Link"
  type        = string
}

variable "nlb_arn" {
  description = "ARN of the Network Load Balancer the VPC Link targets"
  type        = string
}

variable "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  type        = string
}

variable "stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "dev"
}

variable "endpoint_type" {
  description = "Endpoint type for the REST API (EDGE, REGIONAL, or PRIVATE)"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["EDGE", "REGIONAL", "PRIVATE"], var.endpoint_type)
    error_message = "endpoint_type must be EDGE, REGIONAL, or PRIVATE"
  }
}

variable "minimum_compression_size" {
  description = "Minimum response size to compress (0-10485760 bytes). -1 disables compression."
  type        = number
  default     = -1
}

variable "throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 1000
}

variable "throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 2000
}

variable "log_retention_days" {
  description = "CloudWatch log group retention period in days"
  type        = number
  default     = 7
}

variable "logging_level" {
  description = "Logging level for API Gateway (OFF, INFO, ERROR)"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["OFF", "INFO", "ERROR"], var.logging_level)
    error_message = "logging_level must be OFF, INFO, or ERROR"
  }
}

variable "data_trace_enabled" {
  description = "Whether to enable data tracing (logs request/response bodies). WARNING: may log sensitive data."
  type        = bool
  default     = false
}

variable "metrics_enabled" {
  description = "Whether to enable CloudWatch metrics for API Gateway"
  type        = bool
  default     = true
}

variable "xray_tracing_enabled" {
  description = "Whether to enable X-Ray tracing for API Gateway"
  type        = bool
  default     = true
}

variable "create_api_gateway_account" {
  description = "Whether to create the API Gateway account resource for CloudWatch logging. Only one per region."
  type        = bool
  default     = true
}

variable "cache_cluster_enabled" {
  description = "Whether to enable API Gateway cache cluster"
  type        = bool
  default     = false
}

variable "cache_cluster_size" {
  description = "Size of the API Gateway cache cluster (0.5, 1.6, 6.1, 13.5, 28.4, 58.2, 118, 237)"
  type        = string
  default     = "0.5"
}

variable "project" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN for the REST API authorizer"
  type        = string
}

variable "api_version" {
  description = "Current API version (e.g., v1, v2). Used for path-based versioning."
  type        = string
  default     = "v1"
}

variable "deprecated_versions" {
  description = "List of deprecated API versions that are still supported but scheduled for removal"
  type = list(object({
    version     = string
    sunset_date = string # ISO 8601 date format (e.g., 2026-06-01)
  }))
  default = []
}

variable "enable_waf" {
  description = "Whether to enable WAF protection for the API Gateway"
  type        = bool
  default     = false
}

variable "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL to associate with the API Gateway stage. Required if enable_waf is true."
  type        = string
  default     = null
}
