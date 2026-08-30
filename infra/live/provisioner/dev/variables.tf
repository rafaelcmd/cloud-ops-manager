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
  default     = "provisioner"
}

variable "cluster_name" {
  description = "Name of the EKS cluster the pod runs on. Prefixes the IAM role name, matching the api component's convention."
  type        = string
}
