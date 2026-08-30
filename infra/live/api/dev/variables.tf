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
  default     = "dev"
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
# EKS CONFIGURATION
# Variables for the EKS-on-Fargate cluster that hosts the API and Redis
# =============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes control-plane version"
  type        = string
  default     = "1.34"
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API server is reachable from the public internet"
  type        = bool
  default     = true
}

variable "cluster_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "fargate_namespaces" {
  description = "Namespaces routed to Fargate. Pods outside these namespaces won't schedule."
  type        = list(string)
  default     = ["default", "kube-system"]
}

variable "cluster_log_retention_days" {
  description = "CloudWatch retention for EKS control-plane logs"
  type        = number
  default     = 7
}

variable "aws_load_balancer_controller_chart_version" {
  description = "Helm chart version for the AWS Load Balancer Controller"
  type        = string
  default     = "1.8.1"
}

variable "datadog_chart_version" {
  description = "Helm chart version for the Datadog Cluster Agent (datadog/datadog)"
  type        = string
  default     = "3.227.1"
}

variable "notification_email" {
  description = "Email address for SNS observability-alert notifications. Empty string disables the email subscription (alarms still fire to the topic)."
  type        = string
  default     = ""
}

variable "cluster_admin_principal_arns" {
  description = "IAM principal ARNs granted cluster-admin via EKS Access Entries. Add operator IAM users/roles here so they can use kubectl against the cluster."
  type        = list(string)
  default     = []
}

# =============================================================================
# API NLB CONFIGURATION
# The API NLB and target group are Terraform-managed. Kubernetes binds pods to
# this target group through a TargetGroupBinding resource.
# =============================================================================

variable "api_nlb_name" {
  description = "Name of the Terraform-managed internal NLB for the API"
  type        = string
}

variable "api_target_group_name" {
  description = "Name of the Terraform-managed API target group"
  type        = string
}

variable "api_nlb_listener_port" {
  description = "Listener port for the API NLB"
  type        = number
  default     = 80
}

variable "api_target_group_port" {
  description = "Port the API target group forwards traffic to"
  type        = number
  default     = 8080
}

variable "api_target_group_health_check_path" {
  description = "Health check path for API targets"
  type        = string
  default     = "/v1/health"
}

variable "api_nlb_arn_ssm_parameter_name" {
  description = "SSM parameter name used to publish the API NLB ARN"
  type        = string
}

variable "api_nlb_dns_ssm_parameter_name" {
  description = "SSM parameter name used to publish the API NLB DNS name"
  type        = string
}

variable "api_target_group_arn_ssm_parameter_name" {
  description = "SSM parameter name used to publish the API target group ARN"
  type        = string
}

# =============================================================================
# SQS CONFIGURATION
# Variables for SQS queue configuration
# =============================================================================

variable "queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "delay_seconds" {
  description = "The time in seconds that the delivery of all messages in the queue will be delayed"
  type        = number
}

variable "max_message_size" {
  description = "The limit of how many bytes a message can contain before Amazon SQS rejects it"
  type        = number
}

variable "message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message"
  type        = number
}

variable "receive_wait_time_seconds" {
  description = "The time for which a ReceiveMessage call will wait for a message to arrive"
  type        = number
}

variable "ssm_parameter_name" {
  description = "Name of the SSM parameter for storing the queue URL"
  type        = string
}

variable "ssm_parameter_type" {
  description = "Type of the SSM parameter"
  type        = string
}

# =============================================================================
# REDIS CONFIGURATION
# Redis runs as a k8s Deployment (see /k8s/redis/). We only need to publish the
# in-cluster DNS endpoint to SSM so the API can resolve it at runtime — same
# contract the ECS-era module exposed.
# =============================================================================

variable "redis_ssm_parameter_name" {
  description = "SSM parameter name where the Redis host:port endpoint is published"
  type        = string
}

variable "redis_endpoint" {
  description = "host:port the API uses to reach Redis. Defaults to the Service DNS name created by /k8s/redis/service.yaml."
  type        = string
  default     = "redis.default.svc.cluster.local:6379"
}
