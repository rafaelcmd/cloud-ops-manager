variable "name" {
  description = "Name of the Secrets Manager secret. Workloads resolve secrets by name or ARN, so this is a contract with them."
  type        = string
}

variable "description" {
  description = "What the secret holds, shown in the console"
  type        = string
  default     = null
}

variable "alias_name" {
  description = "Alias for the KMS key, including the alias/ prefix"
  type        = string

  validation {
    condition     = startswith(var.alias_name, "alias/")
    error_message = "alias_name must start with \"alias/\"."
  }
}

variable "kms_key_description" {
  description = "Description of the KMS key. Defaults to \"Encrypts <name>\"."
  type        = string
  default     = null
}

variable "kms_deletion_window_in_days" {
  description = "Days the key survives deletion. AWS enforces a minimum of 7, and the key bills for the whole window."
  type        = number
  default     = 7

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "enable_key_rotation" {
  description = "Rotate the KMS key's backing material annually"
  type        = bool
  default     = true
}

variable "recovery_window_in_days" {
  description = "Days a deleted secret can be restored. Zero deletes immediately, which is what lets a torn-down environment reuse the name."
  type        = number
  default     = 7

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 (delete immediately) or between 7 and 30."
  }
}

variable "tags" {
  description = "Tags applied to the secret and its key"
  type        = map(string)
  default     = {}
}
