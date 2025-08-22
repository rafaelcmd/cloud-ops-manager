# =============================================================================
# GENERAL PROJECT CONFIGURATION
# Core variables that define the project, environment, and AWS configuration
# =============================================================================

variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev) used for resource naming and tagging"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
}

variable "service_name" {
  description = "Name of the service being deployed"
  type        = string
}

variable "app_version" {
  description = "Version of the application being deployed"
  type        = string
}

# =============================================================================
# DATADOG CONFIGURATION
# Variables for Datadog integration and monitoring
# =============================================================================

variable "datadog_api_key" {
  description = "Datadog API key for Lambda forwarder"
  type        = string
  sensitive   = true
}

# =============================================================================
# ECS CONFIGURATION
# Variables for ECS cluster, service, and task configuration
# =============================================================================

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "task_family" {
  description = "ECS task definition family name"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for the ECS task"
  type        = number
}

variable "task_memory" {
  description = "Memory (in MiB) for the ECS task"
  type        = number
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
}

variable "container_port" {
  description = "Port on which the application container listens"
  type        = number
}

variable "datadog_agent_image" {
  description = "Datadog agent Docker image"
  type        = string
}

variable "app_image_tag" {
  description = "Tag of the application Docker image"
  type        = string
}

# =============================================================================
# LOAD BALANCER CONFIGURATION
# Variables for Application Load Balancer setup
# =============================================================================

variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

variable "target_group_name" {
  description = "Name of the ALB target group"
  type        = string
}

variable "health_check_path" {
  description = "Path for ALB health checks"
  type        = string
}

# =============================================================================
# LAMBDA CONFIGURATION
# Variables for Lambda function (Datadog forwarder) configuration
# =============================================================================

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime for the Lambda function"
  type        = string
}

variable "lambda_timeout" {
  description = "Timeout for the Lambda function in seconds"
  type        = number
}

variable "lambda_memory_size" {
  description = "Memory size for the Lambda function in MB"
  type        = number
}
