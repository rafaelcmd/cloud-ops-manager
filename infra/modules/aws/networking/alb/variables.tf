variable "cloud_ops_manager_api_security_group_id" {
  type        = string
  description = "Security Group ID"
}

variable "cloud_ops_manager_api_public_subnet_ids" {
  type        = list(string)
  description = "Public subnet ids list"
}

variable "cloud_ops_manager_vpc_id" {
  description = "VPC ID for the ALB"
  type        = string
}

variable "cloud_ops_manager_ecs_alb_sg" {
  type        = string
  description = "Security Group ID for ECS"
}