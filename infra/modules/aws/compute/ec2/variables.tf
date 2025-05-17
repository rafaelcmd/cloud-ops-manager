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

variable "cloud_ops_manager_consumer_deploy_bucket_arn" {
  type        = string
  description = "S3 Bucket ARN"
}

variable "nat_gateway_id" {
  type        = string
  description = "NAT Gateway ID"
}

variable "route_table_association_id" {
  type        = string
  description = "Route Table Association ID"
}