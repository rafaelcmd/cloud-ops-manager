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
# MONITORING AND OBSERVABILITY
# Variables related to monitoring, logging, and observability tools
# =============================================================================

variable "datadog_api_key" {
  description = "Datadog API key for monitoring and log forwarding"
  type        = string
  sensitive   = true
}

# =============================================================================
# ECS CLUSTER CONFIGURATION
# Variables specific to Amazon ECS cluster and service configuration
# =============================================================================

variable "cluster_name" {
  description = "Name of the ECS cluster where the service will be deployed"
  type        = string
}

variable "task_family" {
  description = "Family name for the ECS task definition"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for the ECS task (256, 512, 1024, 2048, 4096)"
  type        = number
}

variable "task_memory" {
  description = "Memory (in MiB) for the ECS task"
  type        = number
}

variable "desired_count" {
  description = "Number of desired running tasks for the ECS service"
  type        = number
}

variable "container_port" {
  description = "Port on which the application container listens"
  type        = number
}

variable "datadog_agent_image" {
  description = "Docker image for the Datadog agent sidecar container"
  type        = string
}

variable "app_image_tag" {
  description = "Tag for the application Docker image"
  type        = string
}

# =============================================================================
# APPLICATION LOAD BALANCER CONFIGURATION
# Variables for configuring the Application Load Balancer and target groups
# =============================================================================

variable "alb_name" {
  description = "Name for the Application Load Balancer"
  type        = string
}

variable "target_group_name" {
  description = "Name for the ALB target group"
  type        = string
}

variable "health_check_path" {
  description = "Path for ALB health checks"
  type        = string
}

# =============================================================================
# LAMBDA FUNCTION CONFIGURATION
# Variables for the Datadog log forwarder Lambda function
# =============================================================================

variable "lambda_function_name" {
  description = "Name for the Datadog log forwarder Lambda function"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime environment for the Lambda function"
  type        = string
}

variable "lambda_timeout" {
  description = "Timeout (in seconds) for the Lambda function execution"
  type        = number
}

variable "lambda_memory_size" {
  description = "Memory allocation (in MB) for the Lambda function"
  type        = number
}
