# =============================================================================
# AWS CONFIGURATION
# Variables for AWS region and deployment configuration
# =============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# =============================================================================
# DATADOG API CONFIGURATION
# Variables for Datadog API authentication and access
# =============================================================================

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

# =============================================================================
# IAM ROLE CONFIGURATION
# Variables for Datadog AWS integration IAM role setup
# =============================================================================

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

# =============================================================================
# PROJECT AND ENVIRONMENT CONFIGURATION
# Variables for project identification and environment setup
# =============================================================================

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

# =============================================================================
# LOG FORWARDING CONFIGURATION
# Variables for Datadog log collection and Lambda forwarder integration
# =============================================================================

variable "datadog_forwarder_arn" {
  description = "ARN of the Datadog Lambda forwarder for log collection. If empty, logs_config will not be configured."
  type        = string
  default     = ""

  validation {
    condition     = var.datadog_forwarder_arn == "" || can(regex("^arn:aws:lambda:[a-z0-9-]+:[0-9]{12}:function:[a-zA-Z0-9-_]+$", var.datadog_forwarder_arn))
    error_message = "The datadog_forwarder_arn must be a valid Lambda function ARN or an empty string."
  }
}
