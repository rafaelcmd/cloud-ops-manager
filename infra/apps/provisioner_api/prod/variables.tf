# =============================================================================
# GENERAL PROJECT CONFIGURATION
# Core variables that define the project, environment, and AWS configuration
# =============================================================================

variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "cloudops"
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev) used for resource naming and tagging"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "service_name" {
  description = "Name of the service being deployed"
  type        = string
  default     = "resource-provisioner-api"
}

variable "app_version" {
  description = "Version of the application being deployed"
  type        = string
  default     = "1.0.0"
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
  default     = "cloudops-manager-cluster"
}

variable "task_family" {
  description = "ECS task definition family name"
  type        = string
  default     = "resource-provisioner-api-task"
}

variable "task_cpu" {
  description = "CPU units for the ECS task"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory (in MiB) for the ECS task"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Port on which the application container listens"
  type        = number
  default     = 5000
}

variable "datadog_agent_image" {
  description = "Datadog agent Docker image"
  type        = string
  default     = "public.ecr.aws/datadog/agent:latest"
}

variable "app_image_tag" {
  description = "Tag of the application Docker image"
  type        = string
  default     = "latest"
}

variable "deployment_maximum_percent" {
  description = "Maximum percentage of tasks that can be running during a deployment"
  type        = number
  default     = 150
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum percentage of healthy tasks during a deployment"
  type        = number
  default     = 50
}

variable "platform_version" {
  description = "Platform version for ECS Fargate tasks"
  type        = string
  default     = "1.4.0"
}

variable "force_new_deployment" {
  description = "Whether to force a new deployment of the service"
  type        = bool
  default     = true
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to ECS tasks"
  type        = bool
  default     = false
}

# =============================================================================
# LOAD BALANCER CONFIGURATION
# Variables for Network Load Balancer setup
# =============================================================================

variable "nlb_name" {
  description = "Name of the Network Load Balancer"
  type        = string
  default     = "cloudops-manager-nlb"
}

variable "internal" {
  description = "Whether the load balancer is internal (true) or internet-facing (false)"
  type        = bool
  default     = true
}

variable "load_balancer_type" {
  description = "Type of load balancer to create (network for NLB)"
  type        = string
  default     = "network"
}

variable "target_group_name" {
  description = "Name of the NLB target group"
  type        = string
  default     = "cloudops-manager-tg"
}

variable "target_group_protocol" {
  description = "Protocol for the target group (TCP, UDP, TCP_UDP for NLB)"
  type        = string
  default     = "TCP"
}

variable "target_type" {
  description = "Type of target that you must specify when registering targets (instance, ip)"
  type        = string
  default     = "ip"
}

# =============================================================================
# HEALTH CHECK CONFIGURATION
# Variables for NLB health check configuration
# =============================================================================

variable "health_check_enabled" {
  description = "Whether health checks are enabled for the target group"
  type        = bool
  default     = true
}

variable "health_check_protocol" {
  description = "Protocol to use for health checks (TCP or HTTP for NLB)"
  type        = string
  default     = "TCP"
}

variable "health_check_port" {
  description = "Port to use for health checks"
  type        = string
  default     = "traffic-port"
}

variable "health_check_interval" {
  description = "Approximate amount of time, in seconds, between health checks (10 or 30 for NLB)"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Amount of time, in seconds, during which no response means a failed health check (6 or 10 for NLB)"
  type        = number
  default     = 6
}

variable "healthy_threshold" {
  description = "Number of consecutive health checks successes required before considering an unhealthy target healthy (2-10 for NLB)"
  type        = number
  default     = 3
}

variable "unhealthy_threshold" {
  description = "Number of consecutive health check failures required before considering the target unhealthy (2-10 for NLB)"
  type        = number
  default     = 3
}

# =============================================================================
# LISTENER CONFIGURATION
# Variables for NLB listener configuration
# =============================================================================

variable "listener_port" {
  description = "Port on which the load balancer is listening"
  type        = number
  default     = 80
}

variable "listener_protocol" {
  description = "Protocol for connections from clients to the load balancer (TCP, UDP, TCP_UDP for NLB)"
  type        = string
  default     = "TCP"
}

variable "listener_action_type" {
  description = "Type of action for the default listener rule"
  type        = string
  default     = "forward"
}

# =============================================================================
# LAMBDA CONFIGURATION
# Variables for Lambda function (Datadog forwarder) configuration
# =============================================================================

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "provisioner-api-datadog-forwarder"
}

variable "lambda_runtime" {
  description = "Runtime for the Lambda function"
  type        = string
  default     = "python3.9"
}

variable "lambda_timeout" {
  description = "Timeout for the Lambda function in seconds"
  type        = number
  default     = 120
}

variable "lambda_memory_size" {
  description = "Memory size for the Lambda function in MB"
  type        = number
  default     = 1024
}

# Archive Configuration
variable "archive_type" {
  description = "Type of archive to create for Lambda deployment package"
  type        = string
  default     = "zip"
}

variable "archive_output_path_prefix" {
  description = "Prefix for the archive output path"
  type        = string
  default     = "."
}

# IAM Configuration
variable "iam_role_name_suffix" {
  description = "Suffix for the IAM role name"
  type        = string
  default     = "-role"
}

variable "assume_role_policy" {
  description = "IAM assume role policy document"
  type = object({
    Version = string
    Statement = list(object({
      Action = string
      Effect = string
      Principal = object({
        Service = string
      })
    }))
  })
  default = {
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  }
}

variable "lambda_basic_execution_policy_arn" {
  description = "ARN of the AWS Lambda basic execution policy"
  type        = string
  default     = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

variable "additional_policy_name_suffix" {
  description = "Suffix for the additional IAM policy name"
  type        = string
  default     = "-additional-policy"
}

# Lambda Permission Configuration
variable "permission_statement_id" {
  description = "Statement ID for the Lambda permission"
  type        = string
  default     = "AllowExecutionFromCloudWatchLogs"
}

variable "permission_action" {
  description = "Action for the Lambda permission"
  type        = string
  default     = "lambda:InvokeFunction"
}

variable "permission_principal" {
  description = "Principal for the Lambda permission"
  type        = string
  default     = "logs.amazonaws.com"
}

# CloudWatch Logs Configuration
variable "log_group_name_prefix" {
  description = "Prefix for the CloudWatch log group name"
  type        = string
  default     = "/aws/lambda"
}

# =============================================================================
# SQS CONFIGURATION
# Variables for SQS queue configuration
# =============================================================================

variable "queue_name" {
  description = "Name of the SQS queue"
  type        = string
  default     = "provisioner_queue"
}

variable "delay_seconds" {
  description = "The time in seconds that the delivery of all messages in the queue will be delayed"
  type        = number
  default     = 0
}

variable "max_message_size" {
  description = "The limit of how many bytes a message can contain before Amazon SQS rejects it"
  type        = number
  default     = 262144
}

variable "message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message"
  type        = number
  default     = 345600
}

variable "receive_wait_time_seconds" {
  description = "The time for which a ReceiveMessage call will wait for a message to arrive"
  type        = number
  default     = 20
}

variable "ssm_parameter_name" {
  description = "Name of the SSM parameter for storing the queue URL"
  type        = string
  default     = "/CLOUD_OPS_MANAGER/PROVISIONER_QUEUE_URL"
}

variable "ssm_parameter_type" {
  description = "Type of the SSM parameter"
  type        = string
  default     = "String"
}
