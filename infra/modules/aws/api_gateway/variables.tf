# =============================================================================
# API GATEWAY CONFIGURATION
# Variables for basic API Gateway setup and identification
# =============================================================================

variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "api_description" {
  description = "Description of the API Gateway"
  type        = string
}

# =============================================================================
# VPC LINK CONFIGURATION
# Variables for VPC Link setup and NLB integration
# =============================================================================

variable "vpc_link_name" {
  description = "Name of the VPC Link"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the VPC Link security group will be created"
  type        = string
}

variable "vpc_link_security_group_ids" {
  description = "List of security group IDs for the VPC Link (optional - will create one if empty)"
  type        = list(string)
  default     = []
}

variable "vpc_link_subnet_ids" {
  description = "List of subnet IDs for the VPC Link"
  type        = list(string)
}

variable "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  type        = string
}

variable "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  type        = string
}

# =============================================================================
# STAGE CONFIGURATION
# Variables for API Gateway stage and deployment
# =============================================================================

variable "stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "prod"
}

variable "auto_deploy" {
  description = "Whether to automatically deploy API changes"
  type        = bool
  default     = true
}

# =============================================================================
# INTEGRATION CONFIGURATION
# Variables for backend integration settings
# =============================================================================

variable "integration_timeout_ms" {
  description = "Integration timeout in milliseconds"
  type        = number
  default     = 29000
}

# =============================================================================
# THROTTLING CONFIGURATION
# Variables for API Gateway throttling and rate limiting
# =============================================================================

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

# =============================================================================
# CORS CONFIGURATION
# Variables for Cross-Origin Resource Sharing configuration
# =============================================================================

variable "cors_allow_credentials" {
  description = "Whether to allow credentials in CORS requests"
  type        = bool
  default     = false
}

variable "cors_allow_headers" {
  description = "List of allowed headers for CORS"
  type        = list(string)
  default     = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token"]
}

variable "cors_allow_methods" {
  description = "List of allowed HTTP methods for CORS"
  type        = list(string)
  default     = ["GET", "POST", "OPTIONS"]
}

variable "cors_allow_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_expose_headers" {
  description = "List of headers to expose in CORS responses"
  type        = list(string)
  default     = []
}

variable "cors_max_age" {
  description = "Maximum age for CORS preflight requests in seconds"
  type        = number
  default     = 86400
}

# =============================================================================
# LOGGING AND MONITORING CONFIGURATION
# Variables for CloudWatch logs and monitoring
# =============================================================================

variable "log_retention_days" {
  description = "CloudWatch log group retention period in days"
  type        = number
  default     = 7
}

# =============================================================================
# PROJECT AND ENVIRONMENT CONFIGURATION
# Variables for project identification and resource tagging
# =============================================================================

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
