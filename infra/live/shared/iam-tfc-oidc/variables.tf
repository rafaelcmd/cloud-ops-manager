variable "environment" {
  description = "Environment name (e.g., prod, staging, dev) used for resource naming and tagging"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name used for tagging"
  type        = string
  default     = "internal-developer-platform"
}

variable "aws_region" {
  description = "AWS region where the IAM resources will be managed"
  type        = string
  default     = "us-east-1"
}

variable "tfc_role_name" {
  description = "Name of the IAM role assumed by Terraform Cloud via OIDC"
  type        = string
  default     = "terraform-cloud-oidc-role"
}

variable "tfc_allowed_subs" {
  description = "List of allowed OIDC subject claims for Terraform Cloud"
  type        = list(string)
  default = [
    "organization:internal-developer-platform-org:project:Default Project:workspace:internal-developer-platform-iam-tfc-oidc:run_phase:*",
    "organization:internal-developer-platform-org:project:Default Project:workspace:internal-developer-platform-iam-github-oidc:run_phase:*",
    "organization:internal-developer-platform-org:project:Default Project:workspace:internal-developer-platform-shared-vpc:run_phase:*",
    "organization:internal-developer-platform-org:project:Default Project:workspace:internal-developer-platform-shared-ecr:run_phase:*",
    "organization:internal-developer-platform-org:project:Default Project:workspace:internal-developer-platform-shared-datadog:run_phase:*",
    "organization:internal-developer-platform-org:project:Default Project:workspace:internal-developer-platform-api-dev:run_phase:*",
    "organization:internal-developer-platform-org:project:Default Project:workspace:internal-developer-platform-provisioner-dev:run_phase:*",
    "organization:internal-developer-platform-org:project:Default Project:workspace:internal-developer-platform-api-gateway-dev:run_phase:*"
  ]
}

variable "tfc_policy_arns" {
  description = "Policy ARNs to attach to the TFC OIDC role (use least privilege)"
  type        = list(string)
  default     = []
}
