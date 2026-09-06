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
  description = "Name of the service being deployed"
  type        = string
  default     = "scaffolder"
}

# One table for the whole service: name reservations today, template versions
# and repository records to come. See the key layout in main.tf.

variable "point_in_time_recovery_enabled" {
  description = "Continuous backups for the scaffolder table. Off in dev, on everywhere else."
  type        = bool
  default     = false
}

variable "deletion_protection_enabled" {
  description = "Blocks a destroy from taking the repository inventory with it. Off in dev, on everywhere else."
  type        = bool
  default     = false
}

# Step Functions drops .waitForTaskToken messages on these queues; the worker
# pod consumes them and reports back with SendTaskSuccess or SendTaskFailure.

variable "task_visibility_timeout_seconds" {
  description = "How long a received task is hidden from other consumers. Must exceed the slowest task (a template render plus a GitHub push)."
  type        = number
  default     = 300
}

variable "task_message_retention_seconds" {
  description = "How long an unconsumed task survives. A task older than this has already lost its execution."
  type        = number
  default     = 86400
}

variable "task_max_receive_count" {
  description = "Deliveries before a task is moved to the DLQ"
  type        = number
  default     = 5
}

variable "dlq_message_retention_seconds" {
  description = "How long a dead-lettered task is kept for inspection"
  type        = number
  default     = 1209600
}

# The secret holding the GitHub App's PEM private key and the customer-managed
# key that encrypts it. Terraform owns both; the PEM is written out of band.

variable "secret_recovery_window_in_days" {
  description = "Secrets Manager recovery window. 0 in dev so a destroy/apply cycle can reuse the name; 7 or more anywhere the secret matters."
  type        = number
  default     = 0
}

variable "kms_deletion_window_in_days" {
  description = "How long the GitHub App key survives a destroy. AWS enforces a minimum of 7."
  type        = number
  default     = 7
}
