variable "web_acl_name" {
  description = "Name of the WAF Web ACL"
  type        = string
}

variable "web_acl_description" {
  description = "Description of the WAF Web ACL"
  type        = string
  default     = "WAF Web ACL for API Gateway protection"
}

variable "rate_limit_requests" {
  description = "Maximum number of requests per 5-minute period per IP"
  type        = number
  default     = 2000
}

variable "max_request_body_size" {
  description = "Maximum request body size in bytes (default: 10KB)"
  type        = number
  default     = 10240
}

variable "common_rules_excluded" {
  description = "List of AWS Common Rule Set rules to exclude (count instead of block)"
  type        = list(string)
  default     = []
}

variable "enable_logging" {
  description = "Enable CloudWatch logging for WAF"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain WAF logs"
  type        = number
  default     = 7
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
