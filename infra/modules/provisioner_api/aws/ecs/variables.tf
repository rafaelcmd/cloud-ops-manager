variable "vpc_id" {
  description = "The ID of the VPC where the ECS service will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ECS service"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the target group for the ECS service"
  type        = string
}

variable "alb_sg_id" {
  description = "Security group ID for the ECS task"
  type        = string
}