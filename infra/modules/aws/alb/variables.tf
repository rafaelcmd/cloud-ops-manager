variable "alb_name" {
  description = "The name of the Application Load Balancer"
  type        = string
}

variable "internal" {
  description = "Whether the ALB is internal or internet-facing"
  type        = bool
  default     = false
}

variable "load_balancer_type" {
  description = "The type of load balancer to create (application, gateway, network)"
  type        = string
  default     = "application"
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
  default     = "HTTP"
}

variable "vpc_id" {
  description = "The ID of the VPC where the target group is created"
  type        = string
}

variable "target_type" {
  description = "The type of target for the target group (e.g., instance, ip, lambda)"
  type        = string
  default     = "ip"
}

variable "health_check_path" {
  description = "The path for the health check"
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "The interval between health checks"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "The timeout for health checks"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "The number of consecutive successful health checks required to consider a target healthy"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "The number of consecutive failed health checks required to consider a target unhealthy"
  type        = number
  default     = 2
}

variable "matcher" {
  description = "The HTTP status codes to use when checking for a successful response from a target"
  type        = string
  default     = "200"
}

variable "listener_port" {
  description = "The port on which the listener listens"
  type        = number
  default     = 80
}

variable "listener_protocol" {
  description = "The protocol used by the listener"
  type        = string
  default     = "HTTP"
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