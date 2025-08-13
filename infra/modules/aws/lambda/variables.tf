variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "source_dir" {
  description = "Directory containing the Lambda function source code"
  type        = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.9"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 120
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 1024
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions for the Lambda function"
  type        = number
}

variable "tags" {
  description = "Tags to apply to Lambda resources"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "additional_policies" {
  description = "Additional IAM policies to attach to the Lambda role"
  type        = list(string)
  default     = []
}

variable "additional_inline_policy" {
  description = "Additional inline IAM policy JSON for the Lambda role"
  type        = string
  default     = null
}

variable "allow_cloudwatch_logs_invocation" {
  description = "Allow CloudWatch Logs to invoke this Lambda function"
  type        = bool
  default     = false
}

variable "cloudwatch_logs_source_arn" {
  description = "Optional source ARN for CloudWatch Logs invocation permission"
  type        = string
  default     = null
}
