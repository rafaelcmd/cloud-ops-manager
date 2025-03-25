variable "aws_region" {
  description = "AWS region where the API Gateway will be deployed"
  type        = string
}

variable "stage_name" {
  description = "Stage name for deployment (e.g. dev, prod)"
  type        = string
}
