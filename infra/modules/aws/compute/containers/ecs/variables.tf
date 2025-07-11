variable "cloud_ops_manager_api_public_subnet_ids" {
  description = "List of public subnet IDs for the Cloud Ops Manager API ECS service."
  type        = list(string)
}

variable "cloud_ops_manager_ecs_task_sg" {
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