variable "cloud_ops_manager_public_subnet_id" {
  type        = string
  description = "Public Subnet ID"
}

variable "cloud_ops_manager_security_group_id" {
  type        = string
  description = "Security Group ID"
}

variable "provisioner_consumer_sqs_queue_arn" {
  type        = string
  description = "SQS Queue ARN"
}

variable "provisioner_consumer_sqs_queue_parameter_arn" {
  type        = string
  description = "SQS Queue Parameter ARN"
}