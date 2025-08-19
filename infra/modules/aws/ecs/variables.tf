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
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "service_name" {
  description = "Service name for tagging"
  type        = string
}

variable "app_version" {
  description = "Application version"
  type        = string
}

variable "forwarder_arn" {
  description = "ARN of the Datadog Lambda forwarder"
  type        = string
}

# Variables for parameterization - no defaults, must be provided by caller
variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "task_execution_role_name" {
  description = "Name of the ECS task execution role"
  type        = string
}

variable "task_role_name" {
  description = "Name of the ECS task role"
  type        = string
}

variable "task_policy_name" {
  description = "Name of the ECS task policy"
  type        = string
}

variable "task_family" {
  description = "Family name for the ECS task definition"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for the ECS task"
  type        = string
}

variable "task_memory" {
  description = "Memory (in MiB) for the ECS task"
  type        = string
}

variable "container_port" {
  description = "Port that the application container listens on"
  type        = number
}

variable "app_container_name" {
  description = "Name of the application container"
  type        = string
}

variable "datadog_agent_image" {
  description = "Docker image for the Datadog agent"
  type        = string
}

variable "datadog_site" {
  description = "Datadog site URL"
  type        = string
}

variable "desired_count" {
  description = "Desired number of tasks for the ECS service"
  type        = number
}

variable "deployment_maximum_percent" {
  description = "Maximum percentage of tasks that can be running during deployment"
  type        = number
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum percentage of healthy tasks during deployment"
  type        = number
}

variable "platform_version" {
  description = "Platform version for Fargate"
  type        = string
}

variable "force_new_deployment" {
  description = "Whether to force a new deployment"
  type        = bool
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to the ECS tasks"
  type        = bool
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
}

variable "app_log_group_name" {
  description = "CloudWatch log group name for the application"
  type        = string
}

variable "datadog_log_group_name" {
  description = "CloudWatch log group name for the Datadog agent"
  type        = string
}

variable "security_group_name" {
  description = "Name of the security group for ECS tasks"
  type        = string
}

variable "security_group_description" {
  description = "Description for the ECS security group"
  type        = string
}

variable "app_image_uri" {
  description = "URI of the application container image"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}
