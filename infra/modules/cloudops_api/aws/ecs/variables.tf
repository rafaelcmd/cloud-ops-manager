variable "vpc_id" {
  description = "The ID of the VPC where the ECS service will be deployed"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}