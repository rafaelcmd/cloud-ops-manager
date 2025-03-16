variable "vpc_id" {
  description = "VPC ID for the security group"
  type        = string
}

variable "resource_provisioner_api_private_key" {
  description = "The private key for SSH access"
  type        = string
}