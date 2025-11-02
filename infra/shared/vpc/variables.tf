# =============================================================================
# AWS CONFIGURATION
# Variables for AWS region and basic deployment configuration
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

# =============================================================================
# VPC NETWORK CONFIGURATION
# Variables for VPC and subnet CIDR block configuration
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones to deploy subnets into"
  type        = list(string)
}

# =============================================================================
# PROJECT AND ENVIRONMENT CONFIGURATION
# Variables for project identification and environment setup
# =============================================================================

variable "project" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

# =============================================================================
# RESOURCE TAGGING
# Variables for resource tagging and labeling
# =============================================================================

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
