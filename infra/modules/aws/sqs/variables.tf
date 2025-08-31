# =============================================================================
# SQS QUEUE CONFIGURATION
# Variables for basic SQS queue setup and message handling
# =============================================================================

variable "queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "delay_seconds" {
  description = "The time in seconds that the delivery of all messages in the queue will be delayed"
  type        = number
}

variable "max_message_size" {
  description = "The limit of how many bytes a message can contain before Amazon SQS rejects it"
  type        = number
}

variable "message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message"
  type        = number
}

variable "receive_wait_time_seconds" {
  description = "The time for which a ReceiveMessage call will wait for a message to arrive"
  type        = number
}

# =============================================================================
# SSM PARAMETER CONFIGURATION
# Variables for Systems Manager Parameter Store integration
# =============================================================================

variable "ssm_parameter_name" {
  description = "Name of the SSM parameter for storing the queue URL"
  type        = string
}

variable "ssm_parameter_type" {
  description = "Type of the SSM parameter"
  type        = string
}

# =============================================================================
# RESOURCE TAGGING
# Variables for resource tagging and labeling
# =============================================================================

variable "tags" {
  description = "A map of tags to assign to the SQS queue"
  type        = map(string)
  default     = {}
}
