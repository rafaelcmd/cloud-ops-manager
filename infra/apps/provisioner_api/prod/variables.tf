variable "datadog_api_key" {
  description = "Datadog API key for monitoring"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "service_name" {
  description = "Service name"
  type        = string
}

variable "app_version" {
  description = "Application version"
  type        = string
}

# ECS-specific variables
variable "cluster_name" {
  description = "Name of the ECS cluster"
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

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
}

variable "container_port" {
  description = "Port that the application container listens on"
  type        = number
}

variable "datadog_agent_image" {
  description = "Docker image for the Datadog agent"
  type        = string
}

variable "app_image_tag" {
  description = "Tag for the application Docker image"
  type        = string
}

# ALB-specific variables
variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

variable "target_group_name" {
  description = "Name of the target group"
  type        = string
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
}

# Lambda-specific variables
variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime for the Lambda function"
  type        = string
}

variable "lambda_timeout" {
  description = "Timeout for the Lambda function"
  type        = number
}

variable "lambda_memory_size" {
  description = "Memory size for the Lambda function"
  type        = number
}
