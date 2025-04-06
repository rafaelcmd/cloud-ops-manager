variable "vpc_id" {
  description = "VPC ID for the security group"
  type        = string
}

variable "public_subnet_ip_cidr" {
  description = "Public subnet IP CIDR for the security group"
  type        = string
}