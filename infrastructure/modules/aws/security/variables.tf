variable "vpc_id" {
  description = "VPC ID for the security group"
  type        = string
}

variable "private_key" {
  description = "Keypair name for the EC2 instance"
  type        = string
}