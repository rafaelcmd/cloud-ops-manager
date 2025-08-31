# =============================================================================
# NLB MODULE VARIABLES
# Variables for Network Load Balancer configuration
# =============================================================================

variable "nlb_name" {
  description = "Name of the Network Load Balancer"
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs for the NLB"
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
  description = "The protocol for the target group"
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

# =============================================================================
# HEALTH CHECK VARIABLES
# Variables for target group health check configuration
# =============================================================================

variable "health_check_enabled" {
  description = "Whether health checks are enabled for the target group"
  type        = bool
  default     = true
}

variable "health_check_protocol" {
  description = "The protocol to use for health checks (TCP or HTTP)"
  type        = string
  default     = "TCP"
}

variable "health_check_port" {
  description = "The port to use for health checks"
  type        = string
  default     = "traffic-port"
}

variable "health_check_interval" {
  description = "The interval between health checks (10 or 30 seconds for NLB)"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "The timeout for health checks (6 or 10 seconds for NLB)"
  type        = number
  default     = 6
}

variable "healthy_threshold" {
  description = "The number of consecutive successful health checks required to consider a target healthy (2-10 for NLB)"
  type        = number
  default     = 3
}

variable "unhealthy_threshold" {
  description = "The number of consecutive failed health checks required to consider a target unhealthy (2-10 for NLB)"
  type        = number
  default     = 3
}

# =============================================================================
# LISTENER VARIABLES
# Variables for load balancer listener configuration
# =============================================================================

variable "listener_port" {
  description = "The port on which the listener listens"
  type        = number
}

variable "listener_protocol" {
  description = "The protocol for the listener"
  type        = string
}

variable "listener_action_type" {
  description = "The type of action for the listener default action"
  type        = string
  default     = "forward"
}

# =============================================================================
# GENERAL VARIABLES
# Variables for common resource configuration
# =============================================================================

variable "internal" {
  description = "Whether the load balancer is internal"
  type        = bool
}

variable "load_balancer_type" {
  description = "The type of load balancer"
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
  default     = {}
}
