variable "cloud_ops_manager_public_subnet_id" {
  type        = string
  description = "Public Subnet ID"
}

variable "cloud_ops_manager_api_security_group_id" {
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

variable "cloud_ops_manager_private_subnet_id" {
  type        = string
  description = "Private Subnet ID"
}

variable "cloud_ops_manager_consumer_security_group_id" {
  type        = string
  description = "Security Group ID"
}