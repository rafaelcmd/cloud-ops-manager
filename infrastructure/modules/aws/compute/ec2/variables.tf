variable "environment" {
  type = string
  description = "Deployment environment (e.g., dev, staging, prod)"
}

variable "public_subnet_id" {
  type        = string
  description = "Public Subnet ID"
}

variable "security_group_id" {
  type        = string
  description = "Security Group ID"
}