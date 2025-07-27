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

variable "lb_listener" {
  description = "ARN of the ALB listener for the ECS service"
  type        = string
}

variable "datadog_api_key" {
  description = "Datadog API key for monitoring"
  type        = string
}

variable "aws_region" {
  description = "AWS region where the ECS service will be deployed"
  type        = string
  default     = "us-east-1"
}