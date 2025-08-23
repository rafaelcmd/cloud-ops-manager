variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog application key"
  type        = string
  sensitive   = true
}

variable "role_name" {
  description = "Name of the IAM role for Datadog integration"
  type        = string
  default     = "DatadogIntegrationRole"
}

variable "external_id" {
  description = "External ID for Datadog integration role"
  type        = string
  default     = "datadog-integration-external-id"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "cloudops"
}

variable "datadog_forwarder_arn" {
  description = "ARN of the Datadog Lambda forwarder"
  type        = string
}
