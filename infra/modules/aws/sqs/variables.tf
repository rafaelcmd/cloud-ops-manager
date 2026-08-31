# =============================================================================
# QUEUE
# =============================================================================

variable "queue_name" {
  description = "Name of the queue. Consumers resolve queues by name, so this is a contract with the workloads that read it."
  type        = string
}

variable "delay_seconds" {
  description = "Seconds to delay delivery of every message"
  type        = number
  default     = 0
}

variable "max_message_size" {
  description = "Bytes a message may contain before SQS rejects it"
  type        = number
  default     = 262144 # 256 KiB, the SQS maximum
}

variable "message_retention_seconds" {
  description = "Seconds SQS keeps a message that is never deleted"
  type        = number
  default     = 345600 # 4 days
}

variable "receive_wait_time_seconds" {
  description = "Long-poll duration for ReceiveMessage. Zero means short polling, which costs an API call per empty receive."
  type        = number
  default     = 20

  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "receive_wait_time_seconds must be between 0 and 20."
  }
}

# Must exceed the slowest task the consumer runs, or SQS hands the same message
# to a second consumer while the first is still working on it.
variable "visibility_timeout_seconds" {
  description = "Seconds a received message stays invisible to other consumers"
  type        = number
  default     = 30

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "visibility_timeout_seconds must be between 0 and 43200 (12 hours)."
  }
}

variable "sqs_managed_sse_enabled" {
  description = "Encrypt messages at rest with the SQS-owned key. On by default: API-created queues are unencrypted otherwise, and it costs nothing."
  type        = bool
  default     = true
}

# =============================================================================
# DEAD-LETTER QUEUE
# =============================================================================

variable "enable_dlq" {
  description = "Create a dead-letter queue and a redrive policy pointing at it. Off only for a queue whose failures are genuinely not worth keeping."
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "Deliveries of one message before it is moved to the dead-letter queue"
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1
    error_message = "max_receive_count must be at least 1."
  }
}

variable "dlq_message_retention_seconds" {
  description = "Seconds the dead-letter queue keeps a message. Longer than the main queue: the DLQ is what someone reads days later to work out what broke."
  type        = number
  default     = 1209600 # 14 days, the SQS maximum
}

# =============================================================================
# ACCESS
#
# All three default to empty, and no queue policy is created when they all are.
# Passing them is what turns the queue from "reachable by anything in the account
# with a wide enough identity policy" into a resource that names its
# counterparties.
# =============================================================================

variable "producer_role_arns" {
  description = "Role ARNs allowed to send to the queue"
  type        = list(string)
  default     = []
}

variable "producer_service_principals" {
  description = "AWS service principals allowed to send (e.g. [\"states.amazonaws.com\"]), scoped to this account by aws:SourceAccount"
  type        = list(string)
  default     = []
}

variable "consumer_role_arns" {
  description = "Role ARNs allowed to receive from and delete off the queue"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the queue and its dead-letter queue"
  type        = map(string)
  default     = {}
}
