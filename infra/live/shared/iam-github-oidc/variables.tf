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
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "github_role_name" {
  description = "Name of the IAM role assumed by GitHub Actions via OIDC"
  type        = string
  default     = "github-actions-oidc-role"
}

# A job that references a GitHub Environment presents `environment:<name>` as
# its OIDC subject instead of `ref:refs/heads/main`, so the gated apply and
# destroy jobs need one entry per environment they can run in: `dev`, and
# `dev-auto` when approvals are disabled.
variable "github_allowed_subs" {
  description = "List of allowed OIDC subject claims for GitHub Actions (e.g., repo:org/repo:ref:branch)"
  type        = list(string)
  default = [
    "repo:rafaelcmd/internal-developer-platform:ref:refs/heads/main",
    "repo:rafaelcmd/internal-developer-platform:environment:dev",
    "repo:rafaelcmd/internal-developer-platform:environment:dev-auto"
  ]
}

variable "github_policy_arns" {
  description = "Policy ARNs to attach to the GitHub Actions OIDC role (use least privilege)"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}
