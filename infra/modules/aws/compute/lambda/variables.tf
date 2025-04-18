variable "cloud_ops_manager_api_user_pool_id" {
  description = "The ID of the Cognito User Pool"
  type        = string
}

variable "cloud_ops_manager_api_user_pool_client_id" {
  description = "The ID of the Cognito User Pool Client"
  type        = string
}

variable "cloud_ops_manager_api_deployment_execution_arn" {
  description = "The ARN of the API Gateway execution role"
  type        = string
}