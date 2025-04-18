variable "cloud_ops_manager_api_host" {
  description = "Host of the Cloud Ops Manager API"
  type        = string
}

variable "auth_lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function for authentication"
  type        = string
}