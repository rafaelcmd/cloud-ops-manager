# =============================================================================
# ALB MODULE VARIABLES
# Variables for Application Load Balancer configuration
# =============================================================================

variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

variable "internal" {
  description = "Whether the ALB is internal or internet-facing"
  type        = bool
}

variable "load_balancer_type" {
  description = "The type of load balancer to create (application, gateway, network)"
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs for the ALB"
  type        = list(string)
}

variable "target_group_name" {
  description = "The name of the target group"
  type        = string
}

variable "target_group_port" {
  description = "The port on which the target group listens"
  type        = number
}

variable "target_group_protocol" {
  description = "The protocol used by the target group"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the target group is created"
  type        = string
}

variable "target_type" {
  description = "The type of target for the target group (e.g., instance, ip, lambda)"
  type        = string
}

variable "health_check_path" {
  description = "The path for the health check"
  type        = string
}

variable "health_check_interval" {
  description = "The interval between health checks"
  type        = number
}

variable "health_check_timeout" {
  description = "The timeout for health checks"
  type        = number
}

variable "healthy_threshold" {
  description = "The number of consecutive successful health checks required to consider a target healthy"
  type        = number
}

variable "unhealthy_threshold" {
  description = "The number of consecutive failed health checks required to consider a target unhealthy"
  type        = number
}

variable "matcher" {
  description = "The HTTP status codes to use when checking for a successful response from a target"
  type        = string
}

variable "listener_port" {
  description = "The port on which the listener listens"
  type        = number
}

variable "listener_protocol" {
  description = "The protocol used by the listener"
  type        = string
}

variable "project" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment (e.g., dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
}

# =============================================================================
# SECURITY GROUP VARIABLES
# Variables for security group configuration
# =============================================================================

variable "security_group_name" {
  description = "Name of the security group for the ALB"
  type        = string
}

variable "security_group_description" {
  description = "Description of the security group for the ALB"
  type        = string
}

variable "ingress_from_port" {
  description = "Starting port for ingress rule"
  type        = number
}

variable "ingress_to_port" {
  description = "Ending port for ingress rule"
  type        = number
}

variable "ingress_protocol" {
  description = "Protocol for ingress rule"
  type        = string
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks for ingress rule"
  type        = list(string)
}

variable "egress_from_port" {
  description = "Starting port for egress rule"
  type        = number
}

variable "egress_to_port" {
  description = "Ending port for egress rule"
  type        = number
}

variable "egress_protocol" {
  description = "Protocol for egress rule"
  type        = string
}

variable "egress_cidr_blocks" {
  description = "CIDR blocks for egress rule"
  type        = list(string)
}

# =============================================================================
# LISTENER VARIABLES
# Variables for listener configuration
# =============================================================================

variable "default_action_type" {
  description = "Type of action for the default listener rule"
  type        = string
}
