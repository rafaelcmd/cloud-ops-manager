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
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region where the ECS service will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "cloudops"
}

variable "service_name" {
  description = "Service name for tagging"
  type        = string
  default     = "resource-provisioner-api"
}

variable "app_version" {
  description = "Application version"
  type        = string
  default     = "1.0.0"
}

variable "forwarder_arn" {
  description = "ARN of the Datadog Lambda forwarder"
  type        = string
}
