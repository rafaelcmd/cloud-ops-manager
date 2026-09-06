variable "name" {
  description = "Name of the table. Workloads resolve it from their environment, so this is a contract with them."
  type        = string
}

variable "hash_key" {
  description = "Partition key attribute name"
  type        = string
}

variable "range_key" {
  description = "Sort key attribute name. Null for a table keyed on the partition alone."
  type        = string
  default     = null
}

# Only attributes used by a key or an index belong here. DynamoDB rejects a
# table that declares an attribute nothing keys on, so plain data fields are
# never listed.
variable "attributes" {
  description = "Attributes used by the table's keys and indexes"
  type = list(object({
    name = string
    type = string # S, N or B
  }))

  validation {
    condition     = alltrue([for a in var.attributes : contains(["S", "N", "B"], a.type)])
    error_message = "Attribute type must be S (string), N (number) or B (binary)."
  }
}

variable "global_secondary_indexes" {
  description = "Global secondary indexes. Every key they use must also appear in var.attributes."
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = optional(string)
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string))
    read_capacity      = optional(number)
    write_capacity     = optional(number)
  }))
  default = []
}

# PAY_PER_REQUEST suits bursty, infrequent traffic: provisioned capacity must be
# sized for a peak and is billed whether or not the peak arrives.
variable "billing_mode" {
  description = "PAY_PER_REQUEST or PROVISIONED"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "read_capacity" {
  description = "Read capacity units. Ignored unless billing_mode is PROVISIONED."
  type        = number
  default     = null
}

variable "write_capacity" {
  description = "Write capacity units. Ignored unless billing_mode is PROVISIONED."
  type        = number
  default     = null
}

variable "ttl_attribute_name" {
  description = "Attribute holding an expiry as epoch seconds. Null disables TTL."
  type        = string
  default     = null
}

variable "point_in_time_recovery_enabled" {
  description = "Continuous backups, restorable to any second in the last 35 days. Bills per GB of table size."
  type        = bool
  default     = false
}

variable "deletion_protection_enabled" {
  description = "Refuse to delete the table, including by terraform destroy. Enable for any table holding data worth keeping."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "CMK for server-side encryption. Null uses the AWS-owned key, which is free but cannot be scoped."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the table"
  type        = map(string)
  default     = {}
}
