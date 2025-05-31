variable "api_repository_url" {
  description = "The URL of the ECR repository for the Cloud Ops Manager API."
  type        = string
}

variable "cloud_ops_manager_api_public_subnet_ids" {
  description = "List of public subnet IDs for the Cloud Ops Manager API ECS service."
  type        = list(string)
}

variable "cloud_ops_manager_api_ecs_security_group_id" {
  description = "Security Group ID for the Cloud Ops Manager API ECS service."
  type        = string
}

variable "cloud_ops_manager_api_ecs_tg_arn" {
  description = "ARN of the target group for the Cloud Ops Manager API ECS service."
  type        = string
}

variable "cloud_ops_manager_api_ecs_listener" {
  description = "ARN of the listener for the Cloud Ops Manager API ECS service."
  type        = string
}

variable "cloud_ops_manager_api_ecs_tg" {
  description = "Target group for the Cloud Ops Manager API ECS service."
  type        = any
}