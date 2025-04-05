variable "public_subnet_id" {
  type        = string
  description = "Public Subnet ID"
}

variable "security_group_id" {
  type        = string
  description = "Security Group ID"
}

variable "sqs_queue_arn" {
  type        = string
  description = "SQS Queue ARN"
}

variable "sqs_queue_parameter_arn" {
  type        = string
  description = "SQS Queue Parameter ARN"
}