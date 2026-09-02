variable "name" {
  description = "Name of the topic. Alarms reference it by ARN, so changing it re-creates the topic and invalidates every email confirmation."
  type        = string
}

# A map, not a list, and the keys are labels the caller chooses:
#
#   subscriptions = {
#     ops-email = { protocol = "email", endpoint = var.notification_email }
#   }
#
# The keys become Terraform addresses, so they must be known at plan time — which
# is exactly why they cannot be derived from the endpoints, since an endpoint may
# be an ARN that does not exist yet. Email subscriptions stay pending until the
# recipient confirms them, so a stable label is also what stops an unrelated
# change from costing another round of confirmation mail.
variable "subscriptions" {
  description = "Subscriptions to create, keyed by a caller-chosen label"
  type = map(object({
    protocol = string
    endpoint = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for s in values(var.subscriptions) :
      contains(["email", "email-json", "https", "http", "sqs", "lambda", "sms"], s.protocol)
    ])
    error_message = "Subscription protocol must be one of: email, email-json, https, http, sqs, lambda, sms."
  }
}

variable "publisher_service_principals" {
  description = "AWS service principals allowed to publish (e.g. [\"events.amazonaws.com\"]), scoped to this account. CloudWatch alarms in this account need no entry."
  type        = list(string)
  default     = []
}

variable "kms_master_key_id" {
  description = "KMS key for encrypting messages at rest. Null leaves the topic unencrypted, which is appropriate for alarm metadata."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the topic"
  type        = map(string)
  default     = {}
}
