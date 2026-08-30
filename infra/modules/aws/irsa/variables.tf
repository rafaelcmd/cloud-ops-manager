variable "role_name" {
  description = "Name of the IAM role the ServiceAccount assumes"
  type        = string
}

variable "role_description" {
  description = "Description of the IAM role"
  type        = string
  default     = null
}

# =============================================================================
# CLUSTER OIDC PROVIDER
# =============================================================================

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "Issuer URL of the cluster's OIDC provider, without the https:// scheme (as modules/aws/eks emits it)"
  type        = string

  validation {
    condition     = !startswith(var.oidc_provider_url, "https://")
    error_message = "oidc_provider_url must not include the scheme: IAM condition keys are built from the bare host and path."
  }
}

# =============================================================================
# SERVICE ACCOUNT
# =============================================================================

variable "namespace" {
  description = "Namespace of the ServiceAccount that may assume the role"
  type        = string
}

variable "service_account_name" {
  description = "Name of the ServiceAccount that may assume the role. Must match serviceAccountName in the workload's manifest."
  type        = string
}

variable "create_service_account" {
  description = "Whether to create the ServiceAccount. False when the workload's chart owns it and only the role is needed here."
  type        = bool
  default     = true
}

variable "service_account_labels" {
  description = "Extra labels merged over the module's defaults (app.kubernetes.io/name, app.kubernetes.io/managed-by)"
  type        = map(string)
  default     = {}
}

variable "service_account_annotations" {
  description = "Extra annotations. The eks.amazonaws.com/role-arn annotation is always set by the module and cannot be overridden."
  type        = map(string)
  default     = {}
}

# =============================================================================
# PERMISSIONS
# =============================================================================

variable "policy_json" {
  description = "IAM policy document for the role's own inline-managed policy. Null creates the role with no policy attached."
  type        = string
  default     = null
}

variable "policy_name" {
  description = "Name of the managed policy created from policy_json. Defaults to <role_name>-policy."
  type        = string
  default     = null
}

variable "policy_description" {
  description = "Description of the managed policy created from policy_json"
  type        = string
  default     = null
}

variable "policy_arns" {
  description = "ARNs of existing policies to attach in addition to policy_json"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the role and its policy"
  type        = map(string)
  default     = {}
}
