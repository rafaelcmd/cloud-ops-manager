variable "aws_region" {
  description = "AWS region to create resources in"
  type        = string
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog APP key"
  type        = string
  sensitive   = true
}

variable "aws_account_id" {
  description = "The AWS Account ID where the Datadog integration is created"
  type        = string
}

variable "role_name" {
  description = "The IAM role name for the Datadog integration"
  type        = string
  default     = "DatadogIntegrationRole"
}

variable "aws_partition" {
  description = "The AWS partition (aws, aws-cn, aws-us-gov)"
  type        = string
  default     = "aws"
}