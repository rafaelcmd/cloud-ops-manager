# =============================================================================
# LAMBDA FUNCTION CONFIGURATION
# Variables for basic Lambda function setup and runtime configuration
# =============================================================================

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
}

variable "runtime" {
  description = "Lambda function runtime"
  type        = string
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions for the Lambda function"
  type        = number
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

# =============================================================================
# DEPLOYMENT PACKAGE CONFIGURATION
# Variables for Lambda deployment package and archive configuration
# =============================================================================

variable "archive_type" {
  description = "Type of archive to create for Lambda deployment package"
  type        = string
}

variable "archive_output_path_prefix" {
  description = "Prefix for the archive output path"
  type        = string
}

# =============================================================================
# IAM ROLE AND POLICY CONFIGURATION
# Variables for IAM role creation and policy attachment
# =============================================================================

variable "iam_role_name_suffix" {
  description = "Suffix for the IAM role name"
  type        = string
}

variable "assume_role_policy" {
  description = "IAM assume role policy document"
  type = object({
    Version = string
    Statement = list(object({
      Action = string
      Effect = string
      Principal = object({
        Service = string
      })
    }))
  })
}

variable "lambda_basic_execution_policy_arn" {
  description = "ARN of the AWS Lambda basic execution policy"
  type        = string
}

variable "additional_policy_name_suffix" {
  description = "Suffix for the additional IAM policy name"
  type        = string
}

variable "additional_policies" {
  description = "List of additional IAM policy ARNs to attach to the Lambda role"
  type        = list(string)
  default     = []
}

variable "additional_inline_policy" {
  description = "Additional inline IAM policy for Lambda-specific permissions"
  type        = string
  default     = null
}

# =============================================================================
# LAMBDA PERMISSIONS CONFIGURATION
# Variables for Lambda function invocation permissions
# =============================================================================

variable "allow_cloudwatch_logs_invocation" {
  description = "Whether to allow CloudWatch Logs to invoke the Lambda function"
  type        = bool
  default     = false
}

variable "cloudwatch_logs_source_arn" {
  description = "Source ARN for CloudWatch Logs permissions (optional)"
  type        = string
  default     = null
}

variable "permission_statement_id" {
  description = "Statement ID for the Lambda permission"
  type        = string
}

variable "permission_action" {
  description = "Action for the Lambda permission"
  type        = string
}

variable "permission_principal" {
  description = "Principal for the Lambda permission"
  type        = string
}

# =============================================================================
# LOGGING CONFIGURATION
# Variables for CloudWatch logs setup and retention
# =============================================================================

variable "log_retention_days" {
  description = "CloudWatch log group retention period in days"
  type        = number
}

variable "log_group_name_prefix" {
  description = "Prefix for the CloudWatch log group name"
  type        = string
}

# =============================================================================
# RESOURCE TAGGING
# Variables for resource tagging and labeling
# =============================================================================

variable "tags" {
  description = "A map of tags to assign to the Lambda function"
  type        = map(string)
  default     = {}
}
