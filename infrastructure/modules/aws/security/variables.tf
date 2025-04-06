variable "vpc_id" {
  description = "VPC ID for the security group"
  type        = string
}

variable "ec2_host" {
  description = "IP address for SSH access"
  type        = string
}