variable "aws_region" {
  description = "AWS region where the API Gateway will be deployed"
  type        = string
}

variable "stage_name" {
  description = "Stage name for deployment (e.g. dev, prod)"
  type        = string
}

variable "resource_provisioner_api_host" {
  description = "Host of the Resource Provisioner API"
  type        = string
}